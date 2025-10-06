public struct ObservabilityService {
    public var metricsService: MetricsService
    public var tracesService: TracesService
    public var logsService: LogsService
    
    public init(
        metricsService: MetricsService,
        tracesService: TracesService,
        logsService: LogsService
    ) {
        self.metricsService = metricsService
        self.tracesService = tracesService
        self.logsService = logsService
    }
    
    public func recordMetric(metric: Metric) {
        metricsService.recordMetric(metric: metric)
    }

    public func recordCount(metric: Metric) {
        metricsService.recordCount(metric: metric)
    }

    public func recordIncr(metric: Metric) {
        metricsService.recordIncr(metric: metric)
    }

    public func recordHistogram(metric: Metric) {
        metricsService.recordHistogram(metric: metric)
    }

    public func recordUpDownCounter(metric: Metric) {
        metricsService.recordUpDownCounter(metric: metric)
    }

    public func recordError(error: Error, attributes: [String: AttributeValue]) {
        tracesService.recordError(error: error, attributes: attributes)
    }

    public func recordLog(message: String, severity: Severity, attributes: [String: AttributeValue]) {
        logsService.recordLog(message: message, severity: severity, attributes: attributes)
    }

    public func startSpan(name: String, attributes: [String: AttributeValue]) -> Span {
        tracesService.startSpan(name: name, attributes: attributes)
    }
    
    public func flush() async -> Bool {
        let tracesFlushed = await tracesService.flush()
        let logsFlushed = await logsService.flush()
        let metricsFlushed = await metricsService.flush()
        
        return tracesFlushed && logsFlushed && metricsFlushed
    }
}
