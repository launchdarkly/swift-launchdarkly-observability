@_exported import OpenTelemetryApi
import LaunchDarkly

/// Interface for observability operations in the LaunchDarkly iOS SDK.
/// Provides methods for recording various types of information.
public protocol Observe: AnyObject, MetricsApi, LogsApi, TracesApi, ObserveContext {
    func start(sessionId: String)
    func start()
    /// Record a custom track event as a `track` span.
    ///
    /// Mirrors `LDClient.track(...)` so the same call shape works whether the
    /// event is recorded through the LaunchDarkly client (via the `afterTrack`
    /// hook) or directly through this API. The payload is passed as `properties`,
    /// a plain dictionary, so callers need not depend on `LDValue` — matching the
    /// `properties:` overloads of `recordLog`/`startSpan`.
    /// - Parameters:
    ///   - key: The key for the event.
    ///   - properties: The data associated with the event, if any. Object members
    ///     are attached as span attributes.
    ///   - metricValue: A numeric value used by LaunchDarkly experimentation for
    ///     numeric custom metrics, if any.
    func track(key: String, properties: [String: Any]?, metricValue: Double?)
    /// Manually record a `screen_view` event as a `screen_view` span.
    ///
    /// Use this for screens that automatic capture cannot observe (e.g. pure
    /// SwiftUI navigation). `previous_screen` is resolved through the same shared
    /// screen stack used by automatic capture.
    /// - Parameters:
    ///   - name: The human-readable screen name (`event.name`, required).
    ///   - screenClass: The screen's class/type (`event.screen_class`).
    ///   - screenId: A stable screen identifier (`event.screen_id`).
    ///   - category: An optional screen group (`event.category`).
    ///   - properties: Optional custom attributes, supplied as a plain dictionary
    ///     (same conversion rules as a `track` event's `properties`). They are
    ///     attached at lower precedence than the reserved `event.*` fields, so
    ///     they can never clobber the taxonomy.
    func trackScreenView(name: String, screenClass: String?, screenId: String?, category: String?, properties: [String: Any]?)
}

extension Observe {
    public func trackScreenView(name: String) {
        trackScreenView(name: name, screenClass: nil, screenId: nil, category: nil, properties: nil)
    }

    public func trackScreenView(name: String, category: String?) {
        trackScreenView(name: name, screenClass: nil, screenId: nil, category: category, properties: nil)
    }

    /// Convenience that omits the screen class/id. See the full overload for the
    /// `properties` semantics.
    public func trackScreenView(name: String, category: String? = nil, properties: [String: Any]?) {
        trackScreenView(name: name, screenClass: nil, screenId: nil, category: category, properties: properties)
    }

    /// Convenience overload without `properties`, preserving the prior call shape.
    public func trackScreenView(name: String, screenClass: String?, screenId: String?, category: String?) {
        trackScreenView(name: name, screenClass: screenClass, screenId: screenId, category: category, properties: nil)
    }
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

    /// Record a log whose attributes are supplied as a plain dictionary.
    ///
    /// Prefer this over ``recordLog(message:severity:attributes:spanContext:)``
    /// for everyday use: pass native values (`String`, `Bool`, `Int`, `Double`,
    /// arrays, nested dictionaries) and they are converted to OTel attributes with
    /// the same rules as a `track` event's `properties`. The `attributes:`
    /// (`AttributeValue`) overload remains available when you need precise OTel
    /// typing. A distinct label keeps the two overloads unambiguous.
    public func recordLog(message: String, severity: Severity, properties: [String: Any], spanContext: SpanContext? = nil) {
        recordLog(message: message, severity: severity, attributes: properties.toOtelAttributes(), spanContext: spanContext)
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
    /// Start a span with an explicit kind.
    /// - name The name of the span
    /// - attributes The attributes to record with the span
    /// - spanKind The kind of the span (defaults to `.client` for most spans)
    func startSpan(name: String, attributes: [String : AttributeValue], spanKind: SpanKind) -> Span
}

extension TracesApi {
    public func recordError(_ error: any Error) {
        recordError(error, attributes: [:])
    }

    public func startSpan(name: String) -> Span {
        startSpan(name: name, attributes: [:])
    }

    /// Default implementation forwards to ``startSpan(name:attributes:)``, leaving the span kind
    /// to the implementation's default. Conformers that can honor a specific kind override this.
    public func startSpan(name: String, attributes: [String : AttributeValue], spanKind: SpanKind) -> Span {
        startSpan(name: name, attributes: attributes)
    }

    /// Start a span whose attributes are supplied as a plain dictionary.
    ///
    /// Prefer this over ``startSpan(name:attributes:)`` for everyday use: pass
    /// native values and they are converted to OTel attributes with the same
    /// rules as a `track` event's `properties`. The `attributes:`
    /// (`AttributeValue`) overload remains available when you need precise OTel
    /// typing.
    public func startSpan(name: String, properties: [String: Any]) -> Span {
        startSpan(name: name, attributes: properties.toOtelAttributes())
    }

    /// Start a span with an explicit kind whose attributes are supplied as a
    /// plain dictionary. See ``startSpan(name:properties:)``.
    public func startSpan(name: String, properties: [String: Any], spanKind: SpanKind) -> Span {
        startSpan(name: name, attributes: properties.toOtelAttributes(), spanKind: spanKind)
    }
}
