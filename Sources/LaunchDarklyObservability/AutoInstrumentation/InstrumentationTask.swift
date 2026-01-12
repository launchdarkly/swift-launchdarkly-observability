import Foundation

final class InstrumentationTask<Instrument>: AutoInstrumentation {
    private let instrument: Instrument
    private let samplingInterval: TimeInterval
    private let operation: (Instrument) async -> Void
    private var task: Task<Void, Never>?
    private var isRunning = false
    
    init(
        instrument: Instrument,
        samplingInterval: TimeInterval = 5.0,
        operation: @escaping (Instrument) async -> Void
    ) {
        self.instrument = instrument
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
    
    private func startReporting(interval: TimeInterval = 5.0) {
        task = Task(priority: .background) { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.operation(self.instrument)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
}
