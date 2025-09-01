@preconcurrency import OpenTelemetryApi
import OpenTelemetrySdk
import StdoutExporter
import URLSessionInstrumentation

import API
import Interfaces
import Common
import CrashReporter
import CrashReporterLive

public final class ObservabilityClient: Observe {
    private let instrumentationManager: InstrumentationManager
    private let sessionManager: SessionManager
    private let resource: Resource
    private let options: Options
    
    private var cachedSpans = AtomicDictionary<String, Span>()
    private let crashReporter: CrashReporter
    private let urlSessionInstrumentation: URLSessionInstrumentation
    
    private var onWillEndSession: (_ sessionId: String) -> Void {
        { [weak self] sessionId in
            self?.willEndSession(sessionId)
        }
    }
    private var onDidStartSession: (_ sessionId: String) -> Void {
        { [weak self] sessionId in
            self?.didStartSession(sessionId)
        }
    }
    
    public init(sdkKey: String, resource: Resource, options: Options) {
        let sessionManager = SessionManager(options: .init(timeout: options.sessionBackgroundTimeout))
        self.instrumentationManager = .init(sdkKey: sdkKey, options: options, sessionManager: sessionManager)
        self.sessionManager = sessionManager
        self.resource = resource
        self.options = options
        
        let crashReporter = CrashReporter.otelReporter(
            logger: instrumentationManager.otelLogger,
            otelBatchLogRecordProcessor: instrumentationManager.otelBatchLogRecordProcessor
        ) {
            
        }
        self.crashReporter = crashReporter
        defer {
            try? crashReporter.install()
            crashReporter.logPendingCrashReports()
        }
        
        self.urlSessionInstrumentation = URLSessionInstrumentation(
            configuration: URLSessionInstrumentationConfiguration(
                tracer: instrumentationManager.otelTracer
            )
        )
        
        self.sessionManager.start(
            onWillEndSession: onWillEndSession,
            onDidStartSession: onDidStartSession
        )
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
    
    public func flush() {
        // TODO: Implement flush
    }
}

extension ObservabilityClient {
    // NOTE: we are not creating spans for app life cycle
    private func didStartSession(_ id: String) {
        /*
        let span = instrumentationManager.startSpan(
            name: "app.session.started",
            attributes: [:]
        )
        cachedSpans[id] = span
         */
    }
    
    private func willEndSession(_ id: String) {
        /*
        guard let span = cachedSpans[id] else { return }
        span.end()
         */
    }
    
}
