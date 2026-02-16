import Common
import OSLog

protocol InternalObserve: Observe {
    var logClient: LogsApi { get }
}

final class ObservabilityClient: InternalObserve {
    let logClient: LogsApi
    private let tracer: TracesApi
    private let logger: LogsApi
    private let meter: MetricsApi
    private let crashReportsApi: CrashReporting
    private let autoInstrumentation: [AutoInstrumentation]
    private let options: Options
    public var context: ObservabilityContext?
    
    init(
        tracer: TracesApi,
        logger: LogsApi,
        logClient: LogsApi,
        meter: MetricsApi,
        crashReportsApi: CrashReporting,
        autoInstrumentation: [AutoInstrumentation],
        options: Options,
        context: ObservabilityContext?
    ) {
        self.tracer = tracer
        self.logger = logger
        self.logClient = logClient
        self.meter = meter
        self.crashReportsApi = crashReportsApi
        self.autoInstrumentation = autoInstrumentation
        self.options = options
        self.context = context
    }
    
    deinit {
        autoInstrumentation.forEach { $0.stop() }
    }
}

extension ObservabilityClient: Observe {
    func start(sessionId: String) {
        let id: String
        if SessionIdFormatVerifier.isURLPathSafeIdentifier(sessionId) {
            id = sessionId
        } else {
            os_log("%{public}@", log: options.log, type: .error, "Invalid SessionID: Using default format. Session ID \(sessionId) is invalid.")
            id = SecureIDGenerator.generateSecureID()
        }
        
        context?.sessionManager.start(sessionId: id)
        autoInstrumentation.forEach { $0.start() }
    }
    
    func start() {
        context?.sessionManager.start(sessionId: SecureIDGenerator.generateSecureID())
        autoInstrumentation.forEach { $0.start() }
    }
    
    func recordMetric(metric: Metric) {
        meter.recordMetric(metric: metric)
    }
    
    func recordCount(metric: Metric) {
        meter.recordCount(metric: metric)
    }
    
    func recordIncr(metric: Metric) {
        meter.recordIncr(metric: metric)
    }
    
    func recordHistogram(metric: Metric) {
        meter.recordHistogram(metric: metric)
    }
    
    func recordUpDownCounter(metric: Metric) {
        meter.recordUpDownCounter(metric: metric)
    }
    
    func recordLog(message: String, severity: Severity, attributes: [String : AttributeValue]) {
        logger.recordLog(message: message, severity: severity, attributes: attributes)
    }
    
    func recordError(error: any Error, attributes: [String : AttributeValue]) {
        tracer.recordError(error: error, attributes: attributes)
    }

    func startSpan(name: String, attributes: [String : AttributeValue]) -> any Span {
        tracer.startSpan(name: name, attributes: attributes)
    }
}
