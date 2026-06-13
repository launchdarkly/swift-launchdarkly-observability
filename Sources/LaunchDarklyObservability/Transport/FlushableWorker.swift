import Foundation
#if !LD_COCOAPODS
    import Common
#endif

actor FlushableWorker {
    typealias Work = @Sendable (_ isFlushing: Bool) async -> Void

    private let interval: TimeInterval
    private let work: Work

    private var running = false
    private var timer: DispatchSourceTimer?
    private var processingTask: Task<Void, Never>?
    private var continuation: AsyncStream<Bool>.Continuation?
    private var flushPending = false

    init(interval: TimeInterval, work: @escaping Work) {
        self.interval = interval
        self.work = work
    }

    func start() {
        guard !running else { return }
        running = true

        // Serialize all work (ticks and flushes) through a single consumer so a
        // tick and a flush never run concurrently. The element payload is the
        // `isFlushing` flag. `.unbounded` guarantees that an enqueued trigger is
        // never silently dropped.
        var localContinuation: AsyncStream<Bool>.Continuation?
        let stream = AsyncStream<Bool>(bufferingPolicy: .unbounded) { cont in
            localContinuation = cont
        }
        continuation = localContinuation

        processingTask = Task { [weak self] in
            guard let self else { return }
            for await isFlushing in stream {
                if Task.isCancelled { break }
                await self.work(isFlushing)
                if isFlushing {
                    await self.clearFlushPending()
                }
            }
        }

        // Drive periodic ticks from a Dispatch timer rather than a
        // `Task.sleep` loop. The timer fires on a Dispatch queue independent of
        // the Swift cooperative thread pool, so periodic ticks keep being
        // enqueued even when that pool is briefly saturated (e.g. on a busy CI
        // machine). This is what made the interval test flaky.
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(5))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.enqueueTick() }
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        running = false
        timer?.cancel()
        timer = nil
        continuation?.finish()
        continuation = nil
        processingTask?.cancel()
        processingTask = nil
        flushPending = false
    }

    func flush() {
        guard running else { return }
        // Coalesce: while a flush is already queued/in-flight, additional flush
        // requests collapse into the pending one.
        guard !flushPending else { return }
        flushPending = true
        continuation?.yield(true)
    }

    private func enqueueTick() {
        guard running else { return }
        continuation?.yield(false)
    }

    private func clearFlushPending() {
        flushPending = false
    }

    deinit {
        // Repeated here because an actor's `stop()` can't be awaited from `deinit`.
        timer?.cancel()
        continuation?.finish()
        processingTask?.cancel()
    }
}
