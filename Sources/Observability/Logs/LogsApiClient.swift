import Foundation
import OpenTelemetrySdk

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
                         attributes: [String: AttributeValue]) -> ReadableLogRecord? {
        var attributes = attributes
        let sessionId = sessionManager.sessionInfo.id
        if !sessionId.isEmpty {
            attributes[SemanticConvention.sessionId] = .string(sessionId)
        }
        
        let logBuilder = LDLogRecordBuilder(
            sampler: sampler,
            resource: Resource(attributes: options.resourceAttributes),
            clock: MillisClock(),
            instrumentationScope: .init(name: options.serviceName),
            includeSpanContext: true)

        return logBuilder
            .setBody(.string(message))
            .setTimestamp(Date())
            .setSeverity(severity)
            .setAttributes(attributes)
            .readableLogRecord()
    }
}

final class LogsApiClient {
    private let eventQueue: EventQueue
    private let appLogBuilder: AppLogBuilder
    
    init(eventQueue: EventQueue, appLogBuilder: AppLogBuilder) {
        self.eventQueue = eventQueue
        self.appLogBuilder = appLogBuilder
    }
}

extension LogsApiClient: LogsApi {
    public func recordLog(
        message: String,
        severity: Severity,
        attributes: [String: AttributeValue]
    ) {
        Task {
            guard let log = appLogBuilder.buildLog(message: message,
                                                   severity: severity,
                                                   attributes: attributes) else {
                return
            }
            
            await eventQueue.send(LogItem(log: log))
        }
    }
}
