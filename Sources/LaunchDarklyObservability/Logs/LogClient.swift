import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

protocol InternalLogsApi {
    func recordLog(message: String,
                   severity: OpenTelemetryApi.Severity,
                   attributes: [String : OpenTelemetryApi.AttributeValue],
                   spanContext: SpanContext?)
}

extension InternalLogsApi {
    public func recordLog(
        message: String,
        severity: Severity,
        attributes: [String: AttributeValue],
    ) {
        recordLog(message: message, severity: severity, attributes: attributes, spanContext: nil)
    }
}

final class AppLogBuilder {
    private let options: Options
    private let sessionManager: SessionManager
    private let sampler: ExportSampler
    
    init(
        options: Options,
        sessionManager: SessionManager,
        sampler: ExportSampler
    ) {
        self.options = options
        self.sessionManager = sessionManager
        self.sampler = sampler
    }
    
    public func buildLog(message: String,
                         severity: Severity,
                         attributes: [String: AttributeValue],
                         spanContext: SpanContext? = nil) -> ReadableLogRecord? {
        var attributes = attributes
        let sessionId = sessionManager.sessionInfo.id
        if !sessionId.isEmpty {
            attributes[SemanticConvention.sessionId] = .string(sessionId)
        }
        
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
        return recordBuilder.readableLogRecord()
    }
}

final class LogClient: InternalLogsApi {
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
