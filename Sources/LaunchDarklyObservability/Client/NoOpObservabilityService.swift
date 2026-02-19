// Lightweight no-op implementation of Observe used as the default before the Observability plugin is installed.
/// Does not allocate exporters, start tasks, or perform network requests.
final class NoOpObservabilityService: Observe {
    public var context: ObservabilityContext? { nil }

    func start(sessionId: String) {}
    func start() {}

    func recordLog(message: String, severity: Severity, attributes: [String: AttributeValue]) {}
    
    func recordMetric(metric: Metric) { }
    func recordCount(metric: Metric) { }
    func recordIncr(metric: Metric) { }
    func recordHistogram(metric: Metric) { }
    func recordUpDownCounter(metric: Metric) { }

    func recordError(error: any Error, attributes: [String: AttributeValue]) {}

    func startSpan(name: String, attributes: [String: AttributeValue]) -> any Span {
        NoOpTracer().startSpan(name: name, attributes: attributes)
    }
}

extension NoOpObservabilityService {
    static let shared = NoOpObservabilityService()
}
