import Foundation

final class MeasurementTask: AutoInstrumentation {
    private let metricsApi: MetricsApi
    private let samplingInterval: TimeInterval
    private let operation: (MetricsApi) async -> Void
    private var task: Task<Void, Never>?
    private var isRunning = false
    
    init(
        metricsApi: MetricsApi,
        samplingInterval: TimeInterval = 5.0,
        operation: @escaping (MetricsApi) async -> Void
    ) {
        self.metricsApi = metricsApi
        self.samplingInterval = samplingInterval
        self.operation = operation
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        startReporting(interval: samplingInterval)
    }
    
    func stop() {
        isRunning = false
        task?.cancel()
        task = nil
    }
    
    func startReporting(interval: TimeInterval = 5.0) {
        task = Task(priority: .background) { [weak self] in
            guard let self else { return }
            while self.isRunning && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                await self.operation(self.metricsApi)
            }
        }
    }
}
