struct NoOpLogger: LogsApi {
    func recordLog(message: String, severity: Severity, attributes: [String : AttributeValue], spanContext: SpanContext?) {}
    func flush() -> Bool { true}
}
