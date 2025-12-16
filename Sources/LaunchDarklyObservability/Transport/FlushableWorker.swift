import Foundation
#if !LD_COCOAPODS
    import Common
#endif

actor FlushableWorker {
    typealias Work = @Sendable (_ isFlushing: Bool) async -> Void
    private enum Trigger {
        case tick
        case flush
    }
    
    private var task: Task<Void, Never>? = nil
    private let interval: TimeInterval
    private var work: Work
    private var continuation: AsyncStream<Trigger>.Continuation? = nil
    private var pending: Trigger? = nil
    
    init(interval: TimeInterval, work: @escaping Work) {
        self.interval = interval
        self.work = work
    }
    
    func start() {
        guard task == nil else { return }
        
        let stream = AsyncStream<Trigger>(bufferingPolicy: .bufferingNewest(1)) { [weak self] cont in
            Task {
                await self?.setContinuation(cont)
            }
        }
        
        let task = Task { [weak self] in
            guard let self else { return }
            
            let tickTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(seconds: interval)
                    doTrigger(.tick)
                }
            }
            defer {
                tickTask.cancel()
            }

            for await trigger in stream {
                if Task.isCancelled {
                    break
                }
                await work(trigger == .flush)
                await clearPending()
            }
        }
    }
    
    func stop() {
        task?.cancel()
        task = nil
        continuation?.finish()
        continuation = nil
        pending = nil
    }

    func flush() async {
        doTrigger(.flush)
    }
    
    private func doTrigger(_ next: Trigger) {
        guard pending != .flush else {
            // flush is already next
            return
        }
        
        if next == .flush || pending == nil {
            pending = next
            continuation?.yield(next)
        }
    }
    
    private func clearPending() {
        pending = nil
    }
    
    private func setContinuation(_ continuation: AsyncStream<Trigger>.Continuation) {
        self.continuation = continuation
    }
}

