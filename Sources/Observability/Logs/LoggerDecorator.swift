import Foundation
import OpenTelemetrySdk

final class LoggerDecorator: Logger {
    private let options: Options
    private var logger: any Logger { self }
    private let sessionManager: SessionManager
    private let eventQueue: EventQueue
    private let sampler: ExportSampler
    
    init(
        options: Options,
        sessionManager: SessionManager,
        eventQueue: EventQueue,
        sampler: ExportSampler
    ) {
        self.options = options
        self.sessionManager = sessionManager
        self.eventQueue = eventQueue
        self.sampler = sampler
    }
    
    func eventBuilder(name: String) -> EventBuilder {
        /// NoOp Meter,
        DefaultLoggerProvider.instance.get(instrumentationScopeName: "").eventBuilder(name: name)
    }
    
    func logRecordBuilder() -> LogRecordBuilder {
        LDLogRecordBuilder(queue: eventQueue,
                           sampler: sampler,
                           resource: Resource(attributes: options.resourceAttributes),
                           clock: MillisClock(),
                           instrumentationScope: .init(name: options.serviceName),
                           includeSpanContext: true)
    }
}

extension LoggerDecorator: LogsApi {
    public func recordLog(
        message: String,
        severity: Severity,
        attributes: [String: AttributeValue]
    ) {
        var attributes = attributes
        let sessionId = sessionManager.sessionInfo.id
        if !sessionId.isEmpty {
            attributes[SemanticConvention.highlightSessionId] = .string(sessionId)
        }
        logRecordBuilder()
            .setBody(.string(message))
            .setTimestamp(Date())
            .setSeverity(severity)
            .setAttributes(attributes)
            .emit()
    }
    
    public func flush() -> Bool {
        // TODO: Implement flush API since we are using LDLogRecordBuilder now.
//        logRecordProcessor.forceFlush(explicitTimeout: CommonOTelConfiguration.flushTimeout) == .success
        true
    }
}
