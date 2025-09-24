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
    private let context: ObservabilityContext
    
    private var cachedSpans = AtomicDictionary<String, Span>()
    
    public init(context: ObservabilityContext) {
        self.context = context
        let sessionManager = SessionManager(options: .init(timeout: context.options.sessionBackgroundTimeout))
        self.instrumentationManager = Instrumentation.build(
            context: context,
            sessionManager: sessionManager
        )
        self.sessionManager = sessionManager
        
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
