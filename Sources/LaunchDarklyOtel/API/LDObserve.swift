import Foundation
import LaunchDarkly

public final class LDObserve  {
    private let clientQueue = DispatchQueue(label: "com.launchdarkly.LDObserve.client")
    private var _client: Observe
    /// Latest ``setEmbedderClickHandling(_:)`` request, retained because the embedder installs its
    /// click detection independently of - and typically before - observability initialization.
    ///
    /// Guarded by `clientQueue` together with the copy onto the tap detection it configures: reading
    /// the request and writing it through have to be one step, or a request arriving between the two
    /// would be applied and then immediately overwritten by the older value for the rest of the
    /// session.
    private var _embedderHandlesClicks = false
    var client: Observe {
        get {
            clientQueue.sync {
                _client
            }
        }
        set {
            clientQueue.sync(flags: .barrier) {
                _client = newValue
                newValue.context?.userInteractionManager?.embedderHandlesClicks = _embedderHandlesClicks
            }
        }
    }
    public static let shared = LDObserve()
    public var context: ObservabilityContext?

    init(client: Observe = NoOpObservabilityService.shared) {
        self._client = client
    }
}

extension LDObserve {
    public func start(sessionId: String) {
        client.start(sessionId: sessionId)
    }
    
    public func start() {
        client.start()
    }

    /// Declares whether an embedder (Flutter) resolves clicks for its own views and reports them
    /// through ``trackClick(id:tag:classname:text:xpath:screenId:x:y:timestamp:properties:)``.
    ///
    /// While enabled, automatic tap detection skips taps landing on the embedder's render surface, so
    /// each tap is reported once — by the embedder, which is the only side able to describe the element
    /// that was actually pressed. Taps on native views elsewhere in the app (an add-to-app host's own
    /// screens) are unaffected.
    ///
    /// Called by the embedder's plugin when its click detection is installed, and again with `false`
    /// when it is torn down: until then native keeps reporting its own coarse clicks, so a missing
    /// embedder integration degrades rather than silently dropping every click.
    ///
    /// Safe to call before observability is initialized - the embedder's plugin usually boots first -
    /// because the request is retained and applied once a client is installed. Without that, an early
    /// handshake would be lost and every tap would be reported twice: once coarsely by native
    /// detection and once by the embedder.
    public func setEmbedderClickHandling(_ enabled: Bool) {
        // Read the published context outside the queue; `_client` is read inside it, since going
        // through `client` there would re-enter the same serial queue and deadlock.
        let publishedContext = context
        clientQueue.sync(flags: .barrier) {
            _embedderHandlesClicks = enabled
            (publishedContext ?? _client.context)?.userInteractionManager?.embedderHandlesClicks = enabled
        }
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

    public func trackScreenView(name: String, screenClass: String?, screenId: String?, category: String?, properties: [String: Any]?) {
        client.trackScreenView(name: name, screenClass: screenClass, screenId: screenId, category: category, properties: properties)
    }

    public func trackClick(
        id: String?,
        tag: String?,
        classname: String?,
        text: String?,
        xpath: String?,
        screenId: String?,
        x: Int?,
        y: Int?,
        timestamp: TimeInterval?,
        properties: [String: Any]?
    ) {
        client.trackClick(
            id: id,
            tag: tag,
            classname: classname,
            text: text,
            xpath: xpath,
            screenId: screenId,
            x: x,
            y: y,
            timestamp: timestamp,
            properties: properties
        )
    }
}
