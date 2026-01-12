import Foundation
import OSLog
import OpenTelemetrySdk
#if !LD_COCOAPODS
    import Common
#endif

struct ObservabilityClientFactory {
    static func noOp() -> Observe {
        return ObservabilityClient(
            tracer: NoOpTracer(),
            logger: NoOpLogger(),
            logClient: NoOpLogger(),
            meter: NoOpMeter(),
            crashReportsApi: NoOpCrashReport(),
            autoInstrumentation: [],
            options: .init(),
            context: nil
        )
    }
    
    static func instantiate(
        withOptions options: Options,
        mobileKey: String
    ) throws -> (InternalObserve) {
        let appLifecycleManager = AppLifecycleManager()
        let sessionManager = SessionManager(
            options: .init(
                timeout: options.sessionBackgroundTimeout,
                isDebug: options.isDebug,
                log: options.log),
            appLifecycleManager: appLifecycleManager
        )
        
        /// Discuss adding autoInstrumentationSamplingInterval to options worth it
        /// Maybe could be by instrument or single global sampling interval
        let autoInstrumentationSamplingInterval: TimeInterval = 5.0
        var autoInstrumentation = [AutoInstrumentation]()
        let sampler = CustomSampler(sampler: ThreadSafeSampler.shared.sample(_:))
        let eventQueue = EventQueue()
        let batchWorker = BatchWorker(eventQueue: eventQueue, log: options.log)

        let transportService = TransportService(eventQueue: eventQueue,
                                                batchWorker: batchWorker,
                                                sessionManager: sessionManager,
                                                appLifecycleManager: appLifecycleManager)
        
        guard let url = URL(string: options.backendUrl) else {
            throw InstrumentationError.invalidGraphQLUrl
        }
        let graphQLClient = GraphQLClient(endpoint: url)
        
        Task {
            do {
                let samplingConfigClient = DefaultSamplingConfigClient(client: graphQLClient)
                let config = try await samplingConfigClient.getSamplingConfig(mobileKey: mobileKey)
                sampler.setConfig(config)
            } catch {
                os_log("%{public}@", log: options.log, type: .error, "getSamplingConfig failed with error: \(error)")
            }
        }
        
        // MARK: - Logging
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(OTelPath.logsPath) else {
            throw InstrumentationError.invalidLogExporterUrl
        }
        
        let appLogBuilder = AppLogBuilder(options: options, sessionManager: sessionManager, sampler: sampler)
        let logClient = LogClient(eventQueue: eventQueue, appLogBuilder: appLogBuilder)
        let appLogClient = AppLogClient(logLevel: options.logsApiLevel, logger: logClient)
        let logExporter = OtlpLogExporter(endpoint: url)
        Task {
            await batchWorker.addExporter(logExporter)
        }
        if options.instrumentation.memoryWarnings.isEnabled {
            let memoryWarningMonitor = MemoryPressureMonitor(options: options, appLogBuilder: appLogBuilder) { log in
                await eventQueue.send(LogItem(log: log))
            }
            autoInstrumentation.append(memoryWarningMonitor)
        }
        
        let appLifecycleLogger = AppLifecycleLogger(appLifecycleManager: appLifecycleManager, appLogBuilder: appLogBuilder) { log in
            Task {
                await eventQueue.send(LogItem(log: log))
            }
        }
        autoInstrumentation.append(appLifecycleLogger)
        
        // MARK: - Tracing
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(OTelPath.tracesPath) else {
            throw InstrumentationError.invalidTraceExporterUrl
        }
        
        let traceEventExporter = OtlpTraceEventExporter(
            endpoint: url,
            config: .init(headers: options.customHeaders.map({ ($0.key, $0.value) }))
        )
        Task {
            await batchWorker.addExporter(traceEventExporter)
        }
        let tracerDecorator = TracerDecorator(
            options: options,
            sessionManager: sessionManager,
            sampler: sampler,
            eventQueue: eventQueue
        )
        let traceClient = TraceClient(
            options: options.tracesApi,
            tracer: tracerDecorator
        )
        let appTraceClient = AppTraceClient(
            options: options.tracesApi,
            tracingApiClient: traceClient
        )
        if options.instrumentation.urlSession.isEnabled {
            autoInstrumentation.append(
                NetworkInstrumentationManager(
                    options: options,
                    tracer: tracerDecorator,
                    session: sessionManager
                )
            )
        }
        if options.instrumentation.launchTimes.isEnabled {
            let launchTracker = LaunchTracker()
            autoInstrumentation
                .append(
                    InstrumentationTask<TraceClient>(
                        instrument: traceClient,
                        samplingInterval: autoInstrumentationSamplingInterval
                    ) {
                        await launchTracker.trace(using: $0)
                    }
                )
        }
        
        let userInteractionManager = UserInteractionManager(options: options) { interaction in
            interaction.startEndSpan(tracer: tracerDecorator)
        }
        userInteractionManager.start()
        
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(OTelPath.metricsPath) else {
            throw InstrumentationError.invalidTraceExporterUrl
        }
        
        // MARK: - Metrics
        let metricsEventExporter = OtlpMetricEventExporter(
            endpoint: url,
            config: .init(headers: options.customHeaders.map({ ($0.key, $0.value) }))
        )
        Task {
            await batchWorker.addExporter(metricsEventExporter)
        }
        let metricsScheduleExporter = OtlpMetricScheduleExporter(eventQueue: eventQueue)
        let reader = PeriodicMetricReaderBuilder(exporter: metricsScheduleExporter)
            .setInterval(timeInterval: 10.0)
            .build()

        let metricsClient = MetricsApiFactory.make(
            options: options,
            reader: reader
        )
        let appMetricsClient = AppMetricsClient(
            options: options.metricsApi,
            metricsApiClient: metricsClient
        )
        
        if options.instrumentation.memory.isEnabled {
            autoInstrumentation.append(
                MeasurementTask(metricsApi: metricsClient, samplingInterval: autoInstrumentationSamplingInterval) { api in
                    guard let report = MemoryUseManager.memoryReport(log: options.log) else { return }
                    api.recordMetric(
                        metric: .init(name: SemanticConvention.systemMemoryAppUsageBytes, value: Double(report.appMemoryBytes))
                    )
                    api.recordMetric(
                        metric: .init(name: SemanticConvention.systemMemoryAppTotalBytes, value: Double(report.systemTotalBytes))
                    )
                }
            )
        }
        
        if options.instrumentation.cpu.isEnabled {
            autoInstrumentation.append(
                MeasurementTask(metricsApi: metricsClient, samplingInterval: autoInstrumentationSamplingInterval) { api in
                    guard let value = CpuUtilizationManager.currentCPUUsage() else { return }
                    api.recordMetric(
                        metric: .init(name: SemanticConvention.systemCpuUtilization, value: value)
                    )
                }
            )
        }
        
        let crashReporting: CrashReporting
        if options.crashReporting.vendor == .KSCrash {
            crashReporting = try KSCrashReportService(logsApi: logClient, log: options.log)
        } else if options.crashReporting.vendor == .metricKit {
            if #available(iOS 15.0, tvOS 15.0, *) {
                let reporter = MetricKitCrashReporter(logsApi: logClient, logger: options.log)
                crashReporting = reporter
                autoInstrumentation.append(reporter)
            } else {
                /// since MetricKit is only fully available for iOS 15+
                /// we cannot do assumptions on user wants KSCrash as fallback, so
                /// the safe is to disable crash reporting
                crashReporting = NoOpCrashReport()
                os_log("Crash reporting is disabled, MetricKit is not available on this platform version.", log: options.log, type: .info)
            }
        } else {
            crashReporting = NoOpCrashReport()
        }
        
        let context = ObservabilityContext(
            sdkKey: mobileKey,
            options: options,
            appLifecycleManager: appLifecycleManager,
            sessionManager: sessionManager,
            transportService: transportService,
            userInteractionManager: userInteractionManager
        )
        
        transportService.start()
        autoInstrumentation.forEach { $0.start() }
        crashReporting.logPendingCrashReports()
        
        return ObservabilityClient(
            tracer: appTraceClient,
            logger: appLogClient,
            logClient: logClient,
            meter: appMetricsClient,
            crashReportsApi: crashReporting,
            autoInstrumentation: autoInstrumentation,
            options: options,
            context: context
        )
    }
}
