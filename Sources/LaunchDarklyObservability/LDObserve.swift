import Foundation
@_exported import Observability

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
    
    init(client: Observe = ObservabilityClientFactory.noOp()) {
        self._client = client
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
    
    public func flush() -> Bool {
        client.flush()
    }
    
    public func recordLog(message: String, severity: Severity, attributes: [String : AttributeValue]) {
        client.recordLog(message: message, severity: severity, attributes: attributes)
    }
    
    public func recordError(error: any Error, attributes: [String : AttributeValue]) {
        client.recordError(error: error, attributes: attributes)
    }
    
    public func startSpan(name: String, attributes: [String : AttributeValue]) -> any Span {
        client.startSpan(name: name, attributes: attributes)
    }
}
