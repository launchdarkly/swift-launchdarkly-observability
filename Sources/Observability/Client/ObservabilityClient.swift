final class ObservabilityClient {
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
        meter: MetricsApi,
        crashReportsApi: CrashReporting,
        autoInstrumentation: [AutoInstrumentation],
        options: Options,
        context: ObservabilityContext?
    ) {
        self.tracer = tracer
        self.logger = logger
        self.meter = meter
        self.crashReportsApi = crashReportsApi
        self.autoInstrumentation = autoInstrumentation
        self.options = options
        self.context = context
    }
}

extension ObservabilityClient: Observe {
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
    
    func flush() -> Bool {
        tracer.flush() &&
        meter.flush() &&
        logger.flush()
    }
}
