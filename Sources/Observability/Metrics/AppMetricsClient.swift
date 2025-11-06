import OpenTelemetryApi

final class AppMetricsClient: MetricsApi {
    private let options: Options.MetricsAPIOptions
    private let metricsApiClient: MetricsApi
    
    init(options: Options.MetricsAPIOptions, metricsApiClient: MetricsApi) {
        self.options = options
        self.metricsApiClient = metricsApiClient
    }
    
    func recordMetric(metric: Metric) {
        guard options == .enabled else { return }
        metricsApiClient.recordMetric(metric: metric)
    }
    
    func recordCount(metric: Metric) {
        guard options == .enabled else { return }
        metricsApiClient.recordCount(metric: metric)
    }
    
    func recordIncr(metric: Metric) {
        guard options == .enabled else { return }
        metricsApiClient.recordIncr(metric: metric)
    }
    
    func recordHistogram(metric: Metric) {
        guard options == .enabled else { return }
        metricsApiClient.recordHistogram(metric: metric)
    }
    
    func recordUpDownCounter(metric: Metric) {
        guard options == .enabled else { return }
        metricsApiClient.recordUpDownCounter(metric: metric)
    }
}
