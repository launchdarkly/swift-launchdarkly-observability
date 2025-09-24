@preconcurrency import OpenTelemetryApi
import OpenTelemetrySdk

import API
import Instrumentation
import Common
import CrashReporter
import CrashReporterLive

public final class ObservabilityClient: Observe {
    private let instrumentationManager: Instrumentation
    private let sessionManager: SessionManager
    private let resource: Resource
    private let options: Options
    
    private var cachedSpans = AtomicDictionary<String, Span>()
    
    public init(sdkKey: String, resource: Resource, options: Options) {
        let sessionManager = SessionManager(options: .init(timeout: options.sessionBackgroundTimeout))
        self.instrumentationManager = Instrumentation.build(sdkKey: sdkKey, options: options, sessionManager: sessionManager)
        self.sessionManager = sessionManager
        self.resource = resource
        self.options = options
        
        sessionManager.onSessionDidChange = { _ in
            // TODO: create a span
        }
        sessionManager.onStateDidChange = { _, _ in
            // TODO: create a span
            
        }
    }
    
    // MARK: - Instrumentation
    
    public func recordMetric(metric: Metric) {
        instrumentationManager.recordMetric(metric: metric)
    }
    
    public func recordCount(metric: Metric) {
        instrumentationManager.recordCount(metric: metric)
    }
    
    public func recordIncr(metric: Metric) {
        instrumentationManager.recordIncr(metric: metric)
    }
    
    public func recordHistogram(metric: Metric) {
        instrumentationManager.recordHistogram(metric: metric)
    }
    
    public func recordUpDownCounter(metric: Metric) {
        instrumentationManager.recordUpDownCounter(metric: metric)
    }
    
    public func recordError(error: any Error, attributes: [String : AttributeValue]) {
        instrumentationManager.recordError(error: error, attributes: attributes)
    }
    
    public func recordLog(message: String, severity: Severity, attributes: [String : AttributeValue]) {
        instrumentationManager.recordLog(message: message, severity: severity, attributes: attributes)
    }
    
    public func startSpan(name: String, attributes: [String : AttributeValue]) -> any Span {
        instrumentationManager.startSpan(name: name, attributes: attributes)
    }
    
    public func flush() -> Bool {
        instrumentationManager.flush()
    }
}
