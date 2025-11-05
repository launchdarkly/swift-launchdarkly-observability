import Foundation
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterHttp

public struct ObservabilityClientFactory {
    public static func noOp() -> Observe {
        return ObservabilityClient(
            tracer: NoOpTracer(),
            logger: NoOpLogger(),
            meter: NoOpMeter(),
            crashReportsApi: NoOpCrashReport(),
            autoInstrumentation: [],
            options: .init(),
            context: nil
        )
    }
    public static func instantiate(
        withOptions options: Options,
        mobileKey: String
    ) throws -> Observe {
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
        let meter: MetricsApi
        let logger: LogsApi
        let tracer: TracesApi
        
        let eventQueue = EventQueue()
        let batchWorker = BatchWorker(eventQueue: eventQueue, log: options.log)

        let transportService = TransportService(eventQueue: eventQueue, batchWorker: batchWorker, sessionManager: sessionManager)
        
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(OTelPath.logsPath) else {
            throw InstrumentationError.invalidLogExporterUrl
        }
        
        if options.logs == .enabled {
            let appLogBuilder = AppLogBuilder(options: options, sessionManager: sessionManager, sampler: sampler)
            let apiLogger = APILogger(eventQueue: eventQueue, appLogBuilder: appLogBuilder)
            let loggerDecorator = APILoggerDecorator(options: options.logsApiLevel, logger: apiLogger)
            logger = loggerDecorator
            let logExporter = OtlpLogExporter(endpoint: url)
            Task {
                await batchWorker.addExporter(logExporter)
            }
            if options.autoInstrumentation.contains(.memoryWarnings) {
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
        } else {
            logger = NoOpLogger()
        }
        
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(OTelPath.tracesPath) else {
            throw InstrumentationError.invalidTraceExporterUrl
        }
        
        if options.traces == .enabled {
            let tracesExporter = SamplingTraceExporterDecorator(
                exporter: OtlpHttpTraceExporter(
                    endpoint: url,
                    config: .init(headers: options.customHeaders.map({ ($0.key, $0.value) }))
                ),
                sampler: sampler
            )
            let decorator = TracerDecorator(options: options, sessionManager: sessionManager, exporter: tracesExporter)
            /// tracer is enabled
            if options.autoInstrumentation.contains(.urlSession) {
                autoInstrumentation.append(NetworkInstrumentationManager(options: options, tracer: decorator, session: sessionManager))
            }
            tracer = decorator
            if options.autoInstrumentation.contains(.launchTimes) {
                options.launchMeter.subscribe { statistics in
                    for element in statistics {
                        let span = decorator.startSpan(
                            name: "AppStart",
                            attributes: ["start.type": .string(element.launchType.description)],
                            startTime: element.startTime
                        )
                        span.end(time: element.endTime)
                    }
                }
            }
        } else {
            tracer = NoOpTracer()
        }
        
        let userInteractionManager = UserInteractionManager(options: options) { interaction in
            // TODO: move to LD buffering
            if let span = interaction.span() {
                tracer.startSpan(name: span.name, attributes: span.attributes)
            }
        }
        userInteractionManager.start()
        
        guard  let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(OTelPath.metricsPath) else {
            throw InstrumentationError.invalidTraceExporterUrl
        }
        
        if options.metrics == .enabled {
            let metricsExporter = OtlpHttpMetricExporter(
                endpoint: url,
                config: .init(headers: options.customHeaders.map({ ($0.key, $0.value) }))
            )
            let reader = PeriodicMetricReaderBuilder(exporter: metricsExporter)
                .setInterval(timeInterval: 10.0)
                .build()

            meter = MetricsApiFactory.make(
                options: options,
                reader: reader
            )
            
            if options.autoInstrumentation.contains(.memory) {
                autoInstrumentation.append(
                    MeasurementTask(metricsApi: meter, samplingInterval: autoInstrumentationSamplingInterval) { api in
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
            
            if options.autoInstrumentation.contains(.cpu) {
                autoInstrumentation.append(
                    MeasurementTask(metricsApi: meter, samplingInterval: autoInstrumentationSamplingInterval) { api in
                        guard let value = CpuUtilizationManager.currentCPUUsage() else { return }
                        api.recordMetric(
                            metric: .init(name: SemanticConvention.systemCpuUtilization, value: value)
                        )
                    }
                )
            }
        } else {
            meter = NoOpMeter()
        }
        
        let crashReporting: CrashReporting
        if options.crashReporting == .enabled {
            crashReporting = try KSCrashReportService(logsApi: logger, log: options.log)
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

        return ObservabilityClient(
            tracer: tracer,
            logger: logger,
            meter: meter,
            crashReportsApi: crashReporting,
            autoInstrumentation: autoInstrumentation,
            options: options,
            context: context
        )
    }
}
