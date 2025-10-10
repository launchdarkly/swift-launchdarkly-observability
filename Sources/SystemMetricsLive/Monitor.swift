import Foundation

final class Monitor<T> {
    private var timer: Timer?
    private let interval: TimeInterval
    private let sampleProvider: () -> T?
    private let onSample: (T) -> Void

    init(interval: TimeInterval, sampleProvider: @escaping () -> T?, onSample: @escaping (T) -> Void) {
        self.interval = interval
        self.sampleProvider = sampleProvider
        self.onSample = onSample
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, let sample = self.sampleProvider() else { return }
            self.onSample(sample)
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
