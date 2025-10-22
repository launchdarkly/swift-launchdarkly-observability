import Foundation

protocol AutoInstrumentation {
    func start()
    func stop()
}

struct MeasurementTaskFactory {
    static func make(
        metricsApi: MetricsApi,
        samplingInterval: TimeInterval,
        operation: @escaping (MetricsApi) async -> Void
    ) -> AutoInstrumentation {
        MeasurementTask(metricsApi: metricsApi, samplingInterval: samplingInterval, operation: operation)
    }
}
