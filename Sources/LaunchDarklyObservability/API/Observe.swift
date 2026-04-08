@_exported import OpenTelemetryApi

/// Interface for observability operations in the LaunchDarkly iOS SDK.
/// Provides methods for recording various types of information.
public protocol Observe: AnyObject, MetricsApi, LogsApi, TracesApi, ObserveContext {
    func start(sessionId: String)
    func start()
}

/// Context for transfer data from Observability to SessionReplay during initialization
public protocol ObserveContext {
    var context: ObservabilityContext? { get }
}

public protocol MetricsApi {
    /// Record a metric value.
    /// - metric The metric to record
    func recordMetric(metric: Metric)
    /// Record a count metric.
    /// - metric The count metric to record
    func recordCount(metric: Metric)
    /// Record an increment metric.
    /// - metric The increment metric to record
    func recordIncr(metric: Metric)
    /// Record a histogram metric.
    /// - metric The histogram metric to record
    func recordHistogram(metric: Metric)
    /// Record an up/down counter metric.
    /// - metric The up/down counter metric to record
    func recordUpDownCounter(metric: Metric)
}

public protocol LogsApi {
    /// Record a log message with optional span context for trace-log correlation.
    func recordLog(message: String, severity: Severity, attributes: [String : AttributeValue], spanContext: SpanContext?)
}

extension LogsApi {
    public func recordLog(message: String, severity: Severity, attributes: [String : AttributeValue]) {
        recordLog(message: message, severity: severity, attributes: attributes, spanContext: nil)
    }

    public func recordLog(message: String, severity: Severity, spanContext: SpanContext? = nil) {
        recordLog(message: message, severity: severity, attributes: [:], spanContext: spanContext)
    }
}

public protocol TracesApi {
    /// Record an error.
    /// - error The error to record
    /// - attributes The attributes to record with the error
    func recordError(_ error: any Error, attributes: [String : AttributeValue])
    /// Start a span.
    /// - name The name of the span
    /// - attributes The attributes to record with the span
    func startSpan(name: String, attributes: [String : AttributeValue]) -> Span
}

extension TracesApi {
    public func recordError(_ error: any Error) {
        recordError(error, attributes: [:])
    }

    public func startSpan(name: String) -> Span {
        startSpan(name: name, attributes: [:])
    }
}
