struct NoOpMeter: MetricsApi {
    func recordMetric(metric: Metric) {
    }
    
    func recordCount(metric: Metric) {
    }
    
    func recordIncr(metric: Metric) {
    }
    
    func recordHistogram(metric: Metric) {
    }
    
    func recordUpDownCounter(metric: Metric) {
    }
    
    func flush() -> Bool {
        true
    }
}
