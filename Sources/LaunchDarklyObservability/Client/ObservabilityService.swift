import Foundation
import OpenTelemetrySdk
import OSLog
#if !LD_COCOAPODS
    import Common
#endif

final class ObservabilityService: InternalObserve {
    var logClient: LogsApi { loggerClient }
    private let logger: LogsApi
    private let meter: MetricsApi
    private let tracer: TracesApi
    private let options: Options
    private let mobileKey: String
    private let sessionAttributes: [String: AttributeValue]
    public var context: ObservabilityContext?
    
    private let autoInstrumentationSamplingInterval: TimeInterval = 5.0
    private let batchWorker: BatchWorker
    private let transportService: TransportService
    private let sessionManager: SessionManager
    private let eventQueue: EventQueue
    private let appLogBuilder: AppLogBuilder
    private let appLifecycleManager: AppLifecycleManager
    private let logExporter: OtlpLogExporter
    private let metricsEventExporter: OtlpMetricEventExporter
    private let traceEventExporter: OtlpTraceEventExporter
    
    private let loggerClient: LogClient
    private let appLogClient: AppLogClient
    
    private let metricsClient: MetricsApi
    private let appMetricsClient: AppMetricsClient
    
    private let traceClient: TraceClient
    private let appTraceClient: AppTraceClient
    private let tracerDecorator: TracerDecorator
    
    private var instruments = [AutoInstrumentation]()
    
    private let userInteractionManager: UserInteractionManager
    private var crashReporting: CrashReporting?
    private let sampler: CustomSampler
    private let graphQLClient: GraphQLClient
    
    private var task: Task<Void, Never>?
    
    init(
        options: Options,
        mobileKey: String,
        sessionAttributes: [String: AttributeValue]
    ) throws {
        self.options = options
        self.mobileKey = mobileKey
        self.sessionAttributes = sessionAttributes
        
        // MARK: - Sampler
        let sampler = CustomSampler(sampler: ThreadSafeSampler.shared.sample(_:))
        self.sampler = sampler
        
        // MARK: - AppLifecycleManager
        let appLifecycleManager = AppLifecycleManager()
        self.appLifecycleManager = appLifecycleManager
        
        let sessionManager = SessionManager(
            options: .init(
                timeout: options.sessionBackgroundTimeout,
                isDebug: options.isDebug,
                log: options.log),
            appLifecycleManager: appLifecycleManager
        )
        self.sessionManager = sessionManager
        
        // MARK: - EventQueue
        let eventQueue = EventQueue()
        self.eventQueue = eventQueue
        
        // MARK: - BatchWorker
        let batchWorker = BatchWorker(eventQueue: eventQueue, log: options.log)
        self.batchWorker = batchWorker
        
        let transportService = TransportService(eventQueue: eventQueue,
                                                batchWorker: batchWorker,
                                                sessionManager: sessionManager,
                                                appLifecycleManager: appLifecycleManager)
        self.transportService = transportService
        // MARK: - Logging
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(OTelPath.logsPath) else {
            throw InstrumentationError.invalidLogExporterUrl
        }
        
        let appLogBuilder = AppLogBuilder(options: options, sessionManager: sessionManager, sampler: sampler)
        let logClient = LogClient(eventQueue: eventQueue, appLogBuilder: appLogBuilder)
        self.loggerClient = logClient
        let appLogClient = AppLogClient(logLevel: options.logsApiLevel, logger: logClient)
        self.appLogClient = appLogClient
        let logExporter = OtlpLogExporter(endpoint: url)
        
        self.appLogBuilder = appLogBuilder
        self.logExporter = logExporter
        self.logger = appLogClient
        
        // MARK: - Metrics
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(OTelPath.metricsPath) else {
            throw InstrumentationError.invalidTraceExporterUrl
        }
        
        let metricsEventExporter = OtlpMetricEventExporter(
            endpoint: url,
            config: .init(headers: options.customHeaders.map({ ($0.key, $0.value) }))
        )
        
        self.metricsEventExporter = metricsEventExporter
        let metricsScheduleExporter = OtlpMetricScheduleExporter(eventQueue: eventQueue)
        let reader = PeriodicMetricReaderBuilder(exporter: metricsScheduleExporter)
            .setInterval(timeInterval: 10.0)
            .build()

        let metricsClient = MetricsApiFactory.make(
            options: options,
            reader: reader
        )
        self.metricsClient = metricsClient
        
        let appMetricsClient = AppMetricsClient(
            options: options.metricsApi,
            metricsApiClient: metricsClient
        )
        self.appMetricsClient = appMetricsClient
        self.meter = appMetricsClient
        
        // MARK: - Tracing
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(OTelPath.tracesPath) else {
            throw InstrumentationError.invalidTraceExporterUrl
        }
        
        // MARK: - OtlpTraceEventExporter
        let traceEventExporter = OtlpTraceEventExporter(
            endpoint: url,
            config: .init(headers: options.customHeaders.map({ ($0.key, $0.value) }))
        )
        self.traceEventExporter = traceEventExporter
        
        
        let tracerDecorator = TracerDecorator(
            options: options,
            sessionManager: sessionManager,
            sampler: sampler,
            eventQueue: eventQueue
        )
        self.tracerDecorator = tracerDecorator
        let traceClient = TraceClient(
            options: options.tracesApi,
            tracer: tracerDecorator
        )
        self.traceClient = traceClient
        
        let appTraceClient = AppTraceClient(
            options: options.tracesApi,
            tracingApiClient: traceClient
        )
        self.tracer = appTraceClient
        self.appTraceClient = appTraceClient
        
        let userInteractionManager = UserInteractionManager(options: options)
        self.userInteractionManager = userInteractionManager
        
        
        guard let url = URL(string: options.backendUrl) else {
            throw InstrumentationError.invalidGraphQLUrl
        }
        let graphQLClient = GraphQLClient(endpoint: url)
        self.graphQLClient = graphQLClient
        
        let context = ObservabilityContext(
            sdkKey: mobileKey,
            options: options,
            appLifecycleManager: appLifecycleManager,
            sessionManager: sessionManager,
            transportService: transportService,
            userInteractionManager: userInteractionManager,
            sessionAttributes: sessionAttributes
        )
        self.context = context
    }
}

extension ObservabilityService {
    private func start() async throws {
        let options = self.options
        await batchWorker.addExporter(logExporter)
        await batchWorker.addExporter(metricsEventExporter)
        await batchWorker.addExporter(traceEventExporter)
        
        transportService.start()
        
        // MARK: - Network
        if options.instrumentation.launchTimes.isEnabled {
            let launchTracker = LaunchTracker()            
            instruments
                .append(
                    InstrumentationTask<TraceClient>(
                        instrument: traceClient,
                        samplingInterval: autoInstrumentationSamplingInterval
                    ) {
                        await launchTracker.trace(using: $0)
                    }
                )
        }
        
        if options.instrumentation.urlSession.isEnabled {
            instruments.append(
                NetworkInstrumentationManager(
                    options: options,
                    tracer: tracerDecorator,
                    session: sessionManager
                )
            )
        }
        
        let tracer = tracerDecorator
        userInteractionManager.setYield { interaction in
            interaction.startEndSpan(tracer: tracer)
        }
        userInteractionManager.start()
        
        if options.instrumentation.memory.isEnabled {
            instruments.append(
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
            instruments.append(
                MeasurementTask(metricsApi: metricsClient, samplingInterval: autoInstrumentationSamplingInterval) { api in
                    guard let value = CpuUtilizationManager.currentCPUUsage() else { return }
                    api.recordMetric(
                        metric: .init(name: SemanticConvention.systemCpuUtilization, value: value)
                    )
                }
            )
        }
        
        if options.instrumentation.memoryWarnings.isEnabled {
            let memoryWarningMonitor = MemoryPressureMonitor(options: options, appLogBuilder: appLogBuilder) { [weak self] log in
                guard let self else { return }
                await eventQueue.send(LogItem(log: log))
            }
            instruments.append(memoryWarningMonitor)
        }
        
        let appLifecycleLogger = AppLifecycleLogger(appLifecycleManager: appLifecycleManager, appLogBuilder: appLogBuilder) { [weak self] log in
            guard let self else { return }
            Task {
                await self.eventQueue.send(LogItem(log: log))
            }
        }
        instruments.append(appLifecycleLogger)

        let crashReporting: CrashReporting
        if options.crashReporting.source == .KSCrash {
            crashReporting = try KSCrashReportService(logsApi: logClient, log: options.log)
            crashReporting.logPendingCrashReports()
        } else if options.crashReporting.source == .metricKit {
            if #available(iOS 15.0, tvOS 15.0, *) {
                let reporter = MetricKitCrashReporter(logsApi: logClient, logger: options.log)
                crashReporting = reporter
                crashReporting.logPendingCrashReports()
                instruments.append(reporter)
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
        self.crashReporting = crashReporting
        
        do {
            let samplingConfigClient = DefaultSamplingConfigClient(client: graphQLClient)
            let config = try await samplingConfigClient.getSamplingConfig(mobileKey: mobileKey)
            sampler.setConfig(config)
        } catch {
            os_log("%{public}@", log: options.log, type: .error, "getSamplingConfig failed with error: \(error)")
        }
        
        for instrument in instruments {
            instrument.start()
        }
    }
}

extension ObservabilityService {
    func start(sessionId: String) {
        guard task == nil else { return }
        
        task = Task { [weak self] in
            guard let self else { return }
            let id = SessionIdResolver.resolve(sessionId: sessionId, log: options.log)

            do {
                self.context?.sessionManager.start(sessionId: id)
                try await self.start()
            } catch {
                os_log("%{public}@", log: options.log, type: .error, "Failure starting Observability Service: \(error)")
            }
        }
    }
    
    func start() {
        guard task == nil else { return }
        
        task = Task { [weak self] in
            guard let self else { return }
            
            do {
                self.context?.sessionManager.start(sessionId: SecureIDGenerator.generateSecureID())
                try await self.start()
            } catch {
                os_log("%{public}@", log: options.log, type: .error, "Failure starting Observability Service: \(error)")
            }
        }
    }
}

extension ObservabilityService: Observe {
    func recordLog(
        message: String,
        severity: Severity,
        attributes: [String: AttributeValue]
    ) {
        logger.recordLog(message: message, severity: severity, attributes: attributes)
    }

    func recordMetric(metric: Metric) {
        meter.recordMetric(metric: metric)
    }

    func recordCount(metric: Metric) {
        meter.recordCount(metric: metric)
    }

    func recordIncr(metric: Metric) {
        meter.recordIncr(metric: metric)
    }

    func recordHistogram(metric: Metric) {
        meter.recordHistogram(metric: metric)
    }

    func recordUpDownCounter(metric: Metric) {
        meter.recordUpDownCounter(metric: metric)
    }

    func recordError(
        error: any Error,
        attributes: [String: AttributeValue]
    ) {
        tracer.recordError(error: error, attributes: attributes)
    }

    func startSpan(
        name: String,
        attributes: [String: AttributeValue]
    ) -> any Span {
        tracer.startSpan(name: name, attributes: attributes)
    }
}
