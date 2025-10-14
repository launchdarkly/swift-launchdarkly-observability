import Foundation

@_exported import Observability

public final class LDObserve {
    private let queue = DispatchQueue(label: "com.launchdarkly.observability.sdk.client", attributes: .concurrent)
    private var observabilityService = ObservabilityService.noOp
    public static let shared = LDObserve()
    
    private init() {}
    
    func set(service: ObservabilityService) {
        queue.async(flags: .barrier) {
            self.observabilityService = service
        }
    }
    
    // MARK: - API
    public func recordMetric(metric: Metric) {
        queue.sync {
            observabilityService.recordMetric(metric: metric)
        }
    }
    
    public func recordCount(metric: Metric) {
        queue.sync {
            observabilityService.recordCount(metric: metric)
        }
    }
    
    public func recordIncr(metric: Metric) {
        queue.sync {
            observabilityService.recordIncr(metric: metric)
        }
    }
    
    public func recordHistogram(metric: Metric) {
        queue.sync {
            observabilityService.recordHistogram(metric: metric)
        }
    }
    
    public func recordUpDownCounter(metric: Metric) {
        queue.sync {
            observabilityService.recordUpDownCounter(metric: metric)
        }
    }
    
    public func recordError(error: any Error, attributes: [String : AttributeValue] = [:]) {
        queue.sync {
            observabilityService.recordError(error: error, attributes: attributes)
        }
    }
    
    public func recordLog(message: String, severity: Severity, attributes: [String : AttributeValue] = [:]) {
        queue.sync {
            observabilityService.recordLog(message: message, severity: severity, attributes: attributes)
        }
    }
    
    public func startSpan(name: String, attributes: [String : AttributeValue] = [:]) -> Span {
        queue.sync {
            observabilityService.startSpan(name: name, attributes: attributes)
        }
    }
    
    @discardableResult public func flush() async -> Bool {
        await observabilityService.flush()
    }
}
