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
    private var task: Task<Void, Never>?
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
        self.instrumentationManager = .init(sdkKey: sdkKey, options: options)
        self.sessionManager = SessionManager(options: .init(timeout: options.sessionBackgroundTimeout))
        self.resource = resource
        self.options = options
        
        self.urlSessionInstrumentation = URLSessionInstrumentation(
            configuration: URLSessionInstrumentationConfiguration(
                tracer: instrumentationManager.otelTracer
            )
        )
        
        self.sessionManager.start(
            onWillEndSession: onWillEndSession,
            onDidStartSession: onDidStartSession
        )
        
        let serviceName = options.serviceName
        self.task = Task {
            do {
                let crashReporter = CrashReporter.build(
                    logRecordBuilder: OpenTelemetry.instance.loggerProvider.get(
                        instrumentationScopeName: serviceName
                    ).logRecordBuilder()
                )
                try await crashReporter.install()
                try await crashReporter.logCrashReports()
            } catch let error {
                print("installation failed with error: \(error)")
                // Crash reporter failed to install
                
            }
        }
    }
    
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
    private func didStartSession(_ id: String) {
        let span = instrumentationManager.startSpan(name: "app.session.started", attributes: [:])
        cachedSpans[id] = span
    }
    
    private func willEndSession(_ id: String) {
        guard let span = cachedSpans[id] else { return }
        span.end()
    }
    
}
