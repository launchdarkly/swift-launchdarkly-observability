import Foundation
import OpenTelemetrySdk
import OpenTelemetryApi

final class OTelLogsService {
    private let sessionService: SessionService
    private let options: Options
    // private let exporter: LogRecordExporter
    private let eventQueue: EventQueue
    // private let otelLogger: any OpenTelemetryApi.Logger
    // private let logRecordProcessor: any LogRecordProcessor
    private let resource: Resource
    private let instrumentationScope: InstrumentationScopeInfo
    private let sampler: ExportSampler
    
    init(
        sessionService: SessionService,
        options: Options,
        sampler: ExportSampler,
        eventQueue: EventQueue
    ) {
        //        / Using the default values from OpenTelemetry for Swift
        //        / For reference check:
        //        /https://github.com/open-telemetry/opentelemetry-swift/blob/main/Sources/OpenTelemetrySdk/Logs/Processors/BatchLogRecordProcessor.swift
        //        let processor = BatchLogRecordProcessor(
        //            logRecordExporter: exporter,
        //            scheduleDelay: 5,
        //            exportTimeout: 30,
        //            maxQueueSize: 2048,
        //            maxExportBatchSize: 512
        //        )
        self.sampler = sampler
        self.resource = Resource(attributes: options.resourceAttributes.mapValues { $0.toOTel() })
        //        let provider = LoggerProviderBuilder()
        //            .with(
        //                processors: [
        //                    processor
        //                ]
        //            )
        //            .with(
        //                resource: Resource(attributes: options.resourceAttributes.mapValues { $0.toOTel() })
        //            )
        //            .build()
        
        /// Register custom logger
        //        OpenTelemetry.registerLoggerProvider(
        //            loggerProvider: provider
        //        )
        
        /// Update logger instance
        //        self.otelLogger = OpenTelemetry.instance.loggerProvider.get(
        //            instrumentationScopeName: options.serviceName
        //        )
        //  self.logRecordProcessor = processor
        self.sessionService = sessionService
        self.options = options
        self.eventQueue = eventQueue
        self.instrumentationScope = .init(name: options.serviceName)
    }
    
    // MARK: - API
    
    func recordLog(
        message: String,
        severity: Observability.Severity,
        attributes: [String: Observability.AttributeValue]
    ) {
   
        
        var attributes = attributes
        let sessionId = sessionService.sessionInfo().id
        if !sessionId.isEmpty {
            attributes[SemanticConvention.highlightSessionId] = .string(sessionId)
        }
        
        let logBuilder = ObservabilityLogRecordBuilder(queue: eventQueue,
                                                       sampler: sampler,
                                                       resource: resource,
                                                       clock: MillisClock(),
                                                       instrumentationScope: instrumentationScope,
                                                       includeSpanContext: true)

     
        
        logBuilder.setBody(.string(message))
            .setTimestamp(Date())
            .setSeverity(severity.toOtel())
            .setAttributes(attributes.mapValues { $0.toOTel() })
            .emit()
    }
    
    func flush() async -> Bool {
        return true
        //        await withCheckedContinuation { continuation in
        //            continuation.resume(
        //                returning: logRecordProcessor.forceFlush(explicitTimeout: CommonOTelConfiguration.flushTimeout) == .success
        //            )
        //        }
    }
}
