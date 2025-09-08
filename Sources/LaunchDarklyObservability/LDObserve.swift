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
        OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: "",
            instrumentationVersion: ""
        ).spanBuilder(spanName: "").startSpan()
    }
    func flush() {}
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
    
    public func recordError(error: any Error, attributes: [String : AttributeValue]) {
        lock.lock()
        defer { lock.unlock() }
        client.recordError(error: error, attributes: attributes)
    }
    
    public func recordLog(message: String, severity: Severity, attributes: [String : AttributeValue]) {
        lock.lock()
        defer { lock.unlock() }
        client.recordLog(message: message, severity: severity, attributes: attributes)
    }
    
    public func startSpan(name: String, attributes: [String : AttributeValue]) -> any Span {
        lock.lock()
        defer { lock.unlock() }
        return client.startSpan(name: name, attributes: attributes)
    }
    
    public func flush() {
        lock.lock()
        defer { lock.unlock() }
        client.flush()
    }
}
