import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

final class AppLogBuilder {
    private let options: ObservabilityOptions
    private let sessionManager: SessionManaging
    private let sampler: ExportSampler
    private let globalAttributes: GlobalAttributesStore
    
    init(
        options: ObservabilityOptions,
        sessionManager: SessionManaging,
        sampler: ExportSampler,
        globalAttributes: GlobalAttributesStore = .shared
    ) {
        self.options = options
        self.sessionManager = sessionManager
        self.sampler = sampler
        self.globalAttributes = globalAttributes
    }
    
    /// Builds the record, hands it to the user ``ObservabilityOptions/logProcessors`` and then
    /// applies export sampling. Returns `nil` when the record is sampled out.
    ///
    /// `ReadableLogRecord` is a value type, so processors observe the record but can't change
    /// what is exported.
    public func buildLog(message: String,
                         severity: Severity,
                         attributes: [String: AttributeValue],
                         spanContext: SpanContext? = nil) -> ReadableLogRecord? {
        var attributes = attributes
        let sessionId = sessionManager.sessionInfo.id
        if !sessionId.isEmpty {
            attributes[SemanticConvention.sessionId] = .string(sessionId)
        }
        attributes = globalAttributes.filling(attributes)
        
        let logBuilder = LDLogRecordBuilder(
            sampler: sampler,
            resource: Resource(attributes: options.resourceAttributes),
            clock: MillisClock(),
            instrumentationScope: .init(name: options.serviceName))

        var recordBuilder = logBuilder
            .setBody(.string(message))
            .setTimestamp(Date())
            .setSeverity(severity)
            .setAttributes(attributes)
        if let spanContext {
            recordBuilder = recordBuilder.setSpanContext(spanContext)
        }
        let log = recordBuilder.unsampledLogRecord()
        for processor in options.logProcessors {
            processor.onEmit(logRecord: log)
        }
        return recordBuilder.sample(log)
    }

    /// Flushes the user ``ObservabilityOptions/logProcessors``.
    func forceFlushProcessors(timeout: TimeInterval) {
        for processor in options.logProcessors {
            _ = processor.forceFlush(explicitTimeout: timeout)
        }
    }
}

final class LogClient: LogRecording {
    private let eventQueue: EventQueue
    private let appLogBuilder: AppLogBuilder
    
    init(eventQueue: EventQueue, appLogBuilder: AppLogBuilder) {
        self.eventQueue = eventQueue
        self.appLogBuilder = appLogBuilder
    }
    
    func recordLog(
        message: String,
        severity: Severity,
        attributes: [String: AttributeValue],
        spanContext: SpanContext?
    ) {
        // must be taken in the current thread
        let spanContext = spanContext ?? OpenTelemetry.instance.contextProvider.activeSpan?.context
        Task {
            guard let log = appLogBuilder.buildLog(message: message,
                                                   severity: severity,
                                                   attributes: attributes,
                                                   spanContext: spanContext) else {
                return
            }
            
            await eventQueue.send(LogItem(log: log))
        }
    }
}
