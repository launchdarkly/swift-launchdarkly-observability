import Foundation

@_exported import ApplicationServices

public final class LDObserve {
    private static let queue = DispatchQueue(label: "com.launchdarkly.observability.sdk.client", attributes: .concurrent)
    private static var observabilityService = ObservabilityService.noOp
    private static let shared = ObservabilityService.noOp
    
    static func set(service: ObservabilityService) {
        queue.async(flags: .barrier) {
            self.observabilityService = service
        }
    }
    
    // MARK: - API
    public static func recordMetric(metric: Metric) {
        queue.sync {
            observabilityService.recordMetric(metric: metric)
        }
    }
    
    public static func recordCount(metric: Metric) {
        queue.sync {
            observabilityService.recordCount(metric: metric)
        }
    }
    
    public static func recordIncr(metric: Metric) {
        queue.sync {
            observabilityService.recordIncr(metric: metric)
        }
    }
    
    public static func recordHistogram(metric: Metric) {
        queue.sync {
            observabilityService.recordHistogram(metric: metric)
        }
    }
    
    public static func recordUpDownCounter(metric: Metric) {
        queue.sync {
            observabilityService.recordUpDownCounter(metric: metric)
        }
    }
    
    public static func recordError(error: any Error, attributes: [String : AttributeValue] = [:]) {
        queue.sync {
            observabilityService.recordError(error: error, attributes: attributes)
        }
    }
    
    public static func recordLog(message: String, severity: Severity, attributes: [String : AttributeValue] = [:]) {
        queue.sync {
            observabilityService.recordLog(message: message, severity: severity, attributes: attributes)
        }
    }
    
    public static func startSpan(name: String, attributes: [String : AttributeValue] = [:]) -> Span {
        queue.sync {
            observabilityService.startSpan(name: name, attributes: attributes)
        }
    }
    
    @discardableResult public static func flush() async -> Bool {
        await observabilityService.flush()
    }
}
