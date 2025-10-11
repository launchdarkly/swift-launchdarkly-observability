import Foundation

final class Monitor<T> {
    private let interval: TimeInterval
    private let queue: DispatchQueue
    private var timer: DispatchSourceTimer?
    private let sampleProvider: () -> T?
    private let onSample: (T) -> Void
    
    init(
        interval: TimeInterval = 1.0,
        queue: DispatchQueue = .global(qos: .background),
        sampleProvider: @escaping () -> T?,
        onSample: @escaping (T) -> Void
    ) {
        self.interval = interval
        self.queue = queue
        self.sampleProvider = sampleProvider
        self.onSample = onSample
    }
    
    func start() {
        stop() // prevent duplicate timers
        
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: interval)
        
        timer.setEventHandler { [weak self] in
            guard let self = self, let sample = self.sampleProvider() else { return }
            DispatchQueue.main.async {
                self.onSample(sample)
            }
        }
        
        self.timer = timer
        timer.resume()
    }
    
    func stop() {
        timer?.cancel()
        timer = nil
    }
}

final class MonitorAsyncAwait<T> {
    private let interval: TimeInterval
    private var task: Task<Void, Never>?
    private let sampleProvider: () -> T?
    private let onSample: (T) -> Void
    
    init(
        interval: TimeInterval = 1.0,
        sampleProvider: @escaping () -> T?,
        onSample: @escaping (T) -> Void
    ) {
        self.interval = interval
        self.sampleProvider = sampleProvider
        self.onSample = onSample
    }
    
    func start() {
        guard task == nil else {
            return
        }
        task = Task.detached(priority: .background) { [weak self] in
            guard let self = self, let sample = self.sampleProvider() else { return }
            
            while !Task.isCancelled {
                await MainActor.run {
                    self.onSample(sample)
                }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
    
    func stop() {
        task?.cancel()
        task = nil
    }
}
