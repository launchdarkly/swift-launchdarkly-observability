import Foundation

@_exported import ApplicationServices

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
    
    public func flush() -> Bool {
        queue.sync {
            observabilityService.flush()
        }
    }
}

/*
import Foundation
@preconcurrency import OpenTelemetryApi
import API
import Observability

private final class NoOpClient: Observe {
    func recordMetric(metric: Metric) {}
    func recordCount(metric: Metric) {}
    func recordIncr(metric: Metric) {}
    func recordHistogram(metric: Metric) {}
    func recordUpDownCounter(metric: Metric) {}
    func recordError(error: any Error, attributes: [String : AttributeValue]) {}
    func recordLog(message: String, severity: Severity, attributes: [String : AttributeValue]) {}
    func startSpan(name: String, attributes: [String : AttributeValue]) -> any Span {
        /// No-op implementation of the Tracer
        DefaultTracer.instance.spanBuilder(spanName: "").startSpan()
    }
    func flush() -> Bool { true }
}

public final class LDObserve: @unchecked Sendable, Observe {
    private let lock = NSLock()
    private var client: Observe = NoOpClient()
    
    public static let shared = LDObserve()
    
    private init() {}
    
    // To prevent race conditions when set client
    public func set(client: Observe) {
        lock.lock()
        defer { lock.unlock() }
        self.client = client
    }
    
    public func recordMetric(metric: Metric) {
        lock.lock()
        defer { lock.unlock() }
        client.recordMetric(metric: metric)
    }
    
    public func recordCount(metric: Metric) {
        lock.lock()
        defer { lock.unlock() }
        client.recordCount(metric: metric)
    }
    
    public func recordIncr(metric: Metric) {
        lock.lock()
        defer { lock.unlock() }
        client.recordIncr(metric: metric)
    }
    
    public func recordHistogram(metric: Metric) {
        lock.lock()
        defer { lock.unlock() }
        client.recordHistogram(metric: metric)
    }
    
    public func recordUpDownCounter(metric: Metric) {
        lock.lock()
        defer { lock.unlock() }
        client.recordUpDownCounter(metric: metric)
    }
    
    public func recordError(error: any Error, attributes: [String : AttributeValue] = [:]) {
        lock.lock()
        defer { lock.unlock() }
        client.recordError(error: error, attributes: attributes)
    }
    
    public func recordLog(message: String, severity: Severity, attributes: [String : AttributeValue] = [:]) {
        lock.lock()
        defer { lock.unlock() }
        client.recordLog(message: message, severity: severity, attributes: attributes)
    }
    
    public func startSpan(name: String, attributes: [String : AttributeValue] = [:]) -> any Span {
        lock.lock()
        defer { lock.unlock() }
        return client.startSpan(name: name, attributes: attributes)
    }
    
    public func flush() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return client.flush()
    }
}
*/
