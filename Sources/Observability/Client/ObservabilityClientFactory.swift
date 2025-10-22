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
        let sessionManager = SessionManager(
            options: .init(
                timeout: options.sessionBackgroundTimeout,
                isDebug: options.isDebug,
                log: options.log)
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
        let batchWorker = BatchWorker(eventQueue: eventQueue)

        let transportService = TransportService(eventQueue: eventQueue, batchWorker: batchWorker, sessionManager: sessionManager)
        
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(OTelPath.logsPath) else {
            throw InstrumentationError.invalidLogExporterUrl
        }
        
        if options.logs == .enabled {
            logger = LoggerDecorator(options: options, sessionManager: sessionManager, eventQueue: eventQueue, sampler: sampler)
            let logExporter = OtlpLogExporter(endpoint: url)
            Task {
                await batchWorker.addExporter(logExporter)
            }
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
        } else {
            tracer = NoOpTracer()
        }
        
        let userInteractionManager = UserInteractionManager(options: options) { interaction in
            Task {
                await eventQueue.send(EventQueueItem(payload: interaction))
            }
            
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
                        guard let report = MemoryUseManager.memoryReport() else { return }
                        api.recordMetric(
                            metric: .init(name: SemanticConvention.systemMemoryAppUsageMb, value: Double(report.appMemoryMB))
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
            sessionManager: sessionManager,
            transportService: transportService
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
