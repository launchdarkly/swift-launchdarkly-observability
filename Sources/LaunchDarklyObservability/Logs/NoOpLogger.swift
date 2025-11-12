struct NoOpLogger: LogsApi {
    func recordLog(message: String, severity: Severity, attributes: [String : AttributeValue]) {}
    func flush() -> Bool { true}
}
