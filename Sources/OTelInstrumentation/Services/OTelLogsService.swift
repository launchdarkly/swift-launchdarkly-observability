import Foundation

import OpenTelemetrySdk
import OpenTelemetryApi

import ApplicationServices

final class OTelLogsService {
    private let sessionService: SessionService
    private let options: Options
    private let exporter: LogRecordExporter
    private let otelLogger: any OpenTelemetryApi.Logger
    private let logRecordProcessor: any LogRecordProcessor
    
    init(
        sessionService: SessionService,
        options: Options,
        exporter: LogRecordExporter
    ) {
        
        /// Using the default values from OpenTelemetry for Swift
        /// For reference check:
        ///https://github.com/open-telemetry/opentelemetry-swift/blob/main/Sources/OpenTelemetrySdk/Logs/Processors/BatchLogRecordProcessor.swift
        let processor = BatchLogRecordProcessor(
            logRecordExporter: exporter,
            scheduleDelay: 5,
            exportTimeout: 30,
            maxQueueSize: 2048,
            maxExportBatchSize: 512
        )

        let provider = LoggerProviderBuilder()
            .with(
                processors: [
                    processor
                ]
            )
            .with(
                resource: Resource(attributes: options.resourceAttributes.mapValues { $0.toOTel() })
            )
            .build()
        
        /// Register custom logger
        OpenTelemetry.registerLoggerProvider(
            loggerProvider: provider
        )
        
        /// Update logger instance
        self.otelLogger = OpenTelemetry.instance.loggerProvider.get(
            instrumentationScopeName: options.serviceName
        )
        self.logRecordProcessor = processor
        self.sessionService = sessionService
        self.options = options
        self.exporter = exporter
    }
    
    // MARK: - API
    
    func recordLog(
        message: String,
        severity: DomainModels.Severity,
        attributes: [String: DomainModels.AttributeValue]
    ) {
        var attributes = attributes
        let sessionId = sessionService.sessionInfo().id
        if !sessionId.isEmpty {
            attributes[SemanticConvention.highlightSessionId] = .string(sessionId)
        }
        otelLogger.logRecordBuilder()
            .setBody(.string(message))
            .setTimestamp(Date())
            .setSeverity(severity.toOtel())
            .setAttributes(attributes.mapValues { $0.toOTel() })
            .emit()
    }
    
    func flush() async -> Bool {
        await withCheckedContinuation { continuation in
            continuation.resume(
                returning: logRecordProcessor.forceFlush(explicitTimeout: CommonOTelConfiguration.flushTimeout) == .success
            )
        }
    }
}
