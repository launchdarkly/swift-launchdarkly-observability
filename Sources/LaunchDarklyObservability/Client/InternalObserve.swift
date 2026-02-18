protocol InternalObserve: Observe {
    var logClient: LogsApi { get }
}

// Lightweight no-op implementation of Observe used as the default before the Observability plugin is installed.
/// Does not allocate exporters, start tasks, or perform network requests.
final class NoOpObservabilityService: InternalObserve {
    private let noOpLogger = NoOpLogger()
    private let noOpTracer = NoOpTracer()
    private let noOpMeter = NoOpMeter()

    var logClient: LogsApi { noOpLogger }
    public var context: ObservabilityContext? { nil }

    func start(sessionId: String) {}
    func start() {}

    func recordLog(message: String, severity: Severity, attributes: [String: AttributeValue]) {
        noOpLogger.recordLog(message: message, severity: severity, attributes: attributes)
    }

    func recordMetric(metric: Metric) { noOpMeter.recordMetric(metric: metric) }
    func recordCount(metric: Metric) { noOpMeter.recordCount(metric: metric) }
    func recordIncr(metric: Metric) { noOpMeter.recordIncr(metric: metric) }
    func recordHistogram(metric: Metric) { noOpMeter.recordHistogram(metric: metric) }
    func recordUpDownCounter(metric: Metric) { noOpMeter.recordUpDownCounter(metric: metric) }

    func recordError(error: any Error, attributes: [String: AttributeValue]) {
        noOpTracer.recordError(error: error, attributes: attributes)
    }

    func startSpan(name: String, attributes: [String: AttributeValue]) -> any Span {
        noOpTracer.startSpan(name: name, attributes: attributes)
    }
}

extension NoOpObservabilityService {
    static let shared = NoOpObservabilityService()
}
