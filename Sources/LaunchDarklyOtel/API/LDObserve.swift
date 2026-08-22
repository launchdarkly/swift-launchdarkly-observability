import Foundation
import LaunchDarkly

public final class LDObserve  {
    private let clientQueue = DispatchQueue(label: "com.launchdarkly.LDObserve.client")
    private var _client: Observe
    var client: Observe {
        get {
            clientQueue.sync {
                _client
            }
        }
        set {
            clientQueue.sync(flags: .barrier) {
                _client = newValue
            }
        }
    }
    public static let shared = LDObserve()
    public var context: ObservabilityContext?

    private var _isFlagClientInitialized = false

    /// Whether observability is attached to an initialized `LDClient`, which is the case when the
    /// plugin was registered with one — through `LDObserve.configure(ldClient:context:...)` or
    /// `LDConfig.plugins`.
    ///
    /// `false` after a standalone setup, where no feature-flag SDK is present: nothing can be
    /// evaluated, `LDClient.identify` and `LDClient.track` are unavailable, and telemetry is
    /// attributed through `identify(key:attributes:)` instead. Hosts that support both setups can
    /// read this to hide what the flagging SDK would drive.
    public var isFlagClientInitialized: Bool {
        clientQueue.sync { _isFlagClientInitialized }
    }

    init(client: Observe = NoOpObservabilityService.shared) {
        self._client = client
    }

    /// Records that a feature-flag client registered the plugin.
    func markFlagClientInitialized() {
        clientQueue.sync(flags: .barrier) {
            _isFlagClientInitialized = true
        }
    }
}

extension LDObserve {
    public func start(sessionId: String) {
        client.start(sessionId: sessionId)
    }
    
    public func start() {
        client.start()
    }
}

extension LDObserve: Observe {
    
    public func recordMetric(metric: Metric) {
        client.recordMetric(metric: metric)
    }
    
    public func recordCount(metric: Metric) {
        client.recordCount(metric: metric)
    }
    
    public func recordIncr(metric: Metric) {
        client.recordIncr(metric: metric)
    }
    
    public func recordHistogram(metric: Metric) {
        client.recordHistogram(metric: metric)
    }
    
    public func recordUpDownCounter(metric: Metric) {
        client.recordUpDownCounter(metric: metric)
    }
    
    public func recordLog(message: String, severity: Severity, attributes: [String : AttributeValue], spanContext: SpanContext?) {
        client.recordLog(message: message, severity: severity, attributes: attributes, spanContext: spanContext)
    }
    
    public func recordError(_ error: any Error, attributes: [String : AttributeValue]) {
        client.recordError(error, attributes: attributes)
    }
    
    public func startSpan(name: String, attributes: [String : AttributeValue]) -> any Span {
        client.startSpan(name: name, attributes: attributes)
    }

    public func track(key: String, properties: [String: Any]? = nil, metricValue: Double? = nil) {
        client.track(key: key, properties: properties, metricValue: metricValue)
    }

    public func identify(contextKeys: [String: String], canonicalKey: String, attributes: [String: Any]? = nil) {
        client.identify(contextKeys: contextKeys, canonicalKey: canonicalKey, attributes: attributes)
    }

    public func trackScreenView(name: String, screenClass: String?, screenId: String?, category: String?, properties: [String: Any]?) {
        client.trackScreenView(name: name, screenClass: screenClass, screenId: screenId, category: category, properties: properties)
    }

    public func trackClick(id: String?, tag: String?, text: String?, screenId: String?, x: Int?, y: Int?, properties: [String: Any]?) {
        client.trackClick(id: id, tag: tag, text: text, screenId: screenId, x: x, y: y, properties: properties)
    }
}
