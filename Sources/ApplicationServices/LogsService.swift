@_exported import DomainModels

public struct LogsService {
    public var recordLog: (_ message: String, _ severity: Severity, _ attributes: [String: AttributeValue]) -> Void
    public var flush: () async -> Bool
    
    public init(
        recordLog: @escaping (_: String, _: Severity, _: [String : AttributeValue]) -> Void,
        flush: @escaping () async -> Bool
    ) {
        self.recordLog = recordLog
        self.flush = flush
    }

    public func recordLog(message: String, severity: Severity, attributes: [String: AttributeValue]) {
        recordLog(message, severity, attributes)
    }
}
