import Testing
@testable import LaunchDarklyObservability
import Foundation

@Suite
struct FlushableWorkerTests {
    
    actor Recorder {
        private(set) var events: [(isFlush: Bool, time: Date)] = []
        
        func add(_ isFlush: Bool) {
            events.append((isFlush, Date()))
        }
        
        var flushCount: Int {
            events.filter { $0.isFlush }.count
        }
        
        var tickCount: Int {
            events.filter { !$0.isFlush }.count
        }
    }

    /// A one-shot gate: `wait()` suspends until `open()` is called (and returns immediately
    /// thereafter). Used to hold a unit of work in-flight so a test can deterministically observe
    /// behaviour that depends on work still being pending.
    actor Gate {
        private var isOpen = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func wait() async {
            if isOpen { return }
            await withCheckedContinuation { waiters.append($0) }
        }

        func open() {
            isOpen = true
            let pending = waiters
            waiters.removeAll()
            pending.forEach { $0.resume() }
        }
    }
    
    @Test
    func ticksOccurOnInterval() async throws {
        let recorder = Recorder()
        let worker = FlushableWorker(interval: 0.025) { isFlushing in
            await recorder.add(isFlushing)
        }
        
        await worker.start()
        
        // Wait until at least 1 tick is observed, with a generous timeout.
        // Timeout is intentionally large to tolerate scheduler/thread-pool
        // contention on busy CI machines, which is what made this test flaky.
        let deadline = Date().addingTimeInterval(30)
        while await recorder.tickCount < 1 && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms poll
        }
        
        await worker.stop()
        
        let ticks = await recorder.tickCount
        #expect(ticks >= 1, "Expected at least a few tick executions")
        let flushes = await recorder.flushCount
        #expect(flushes == 0, "No flushes expected without explicit flush call")
    }
    
    @Test
    func flushEmitsImmediatelyAndOnlyOnceWithLargeInterval() async throws {
        let recorder = Recorder()
        let worker = FlushableWorker(interval: 10.0) { isFlushing in
            await recorder.add(isFlushing)
        }
        
        await worker.start()
        try await Task.sleep(nanoseconds: NSEC_PER_SEC) // allow processing
        await worker.flush()
        try await Task.sleep(nanoseconds: NSEC_PER_SEC) // allow processing
        await worker.stop()
        
        let flushes = await recorder.flushCount
        #expect(flushes == 1, "With a large interval and single flush, expect exactly one flush event")
    }
    
    @Test
    func multipleFlushesCoalesceWhilePending() async throws {
        let recorder = Recorder()
        // Gate the flush work so the first flush stays in-flight (its pending flag uncleared) until
        // the test releases it. That's the precondition for coalescing: without the gate the trivial
        // work can finish - clearing the pending flag - before the second flush is issued, which is a
        // legitimate non-coalesced outcome and is what made this test flaky under load.
        let gate = Gate()
        let worker = FlushableWorker(interval: 10.0) { isFlushing in
            await recorder.add(isFlushing)
            if isFlushing { await gate.wait() }
        }
        
        await worker.start()
        
        await worker.flush()
        await worker.flush() // second flush while first is pending should coalesce
        await gate.open()     // release the first flush now that the second has been issued
        try await Task.sleep(nanoseconds: NSEC_PER_SEC)
        await worker.stop()
        
        let flushes = await recorder.flushCount
        #expect(flushes == 1, "Back-to-back flush calls should coalesce into a single execution")
        let ticks = await recorder.tickCount
        #expect(ticks == 0, "No ticks expected with very large interval")
    }
    
    @Test
    func startIsIdempotentDoesNotDoubleTickRate() async throws {
        let recorder = Recorder()
        let interval: TimeInterval = 0.05
        let worker = FlushableWorker(interval: interval) { isFlushing in
            await recorder.add(isFlushing)
        }
        
        await worker.start()
        try await Task.sleep(nanoseconds: NSEC_PER_SEC) // allow processing
        await worker.start() // should be a no-op due to guard
        try await Task.sleep(nanoseconds: NSEC_PER_SEC) // ~0.21s
        await worker.stop()
        
        let ticks = await recorder.tickCount
        #expect(ticks <= 50, "Idempotent start should not create multiple ticking loops")
    }
    
    @Test
    func stopCancelsFurtherEmissions() async throws {
        let recorder = Recorder()
        let worker = FlushableWorker(interval: 0.05) { isFlushing in
            await recorder.add(isFlushing)
        }
        
        await worker.start()
        try await Task.sleep(nanoseconds: 120_000_000)
        await worker.stop()
        let ticksAtStop = await recorder.tickCount
        
        // After stop, there should be no further events
        try await Task.sleep(nanoseconds: 150_000_000)
        let ticksAfter = await recorder.tickCount
        #expect(ticksAfter == ticksAtStop, "No additional events after stop()")
    }
    
    @Test
    func flushImmediatelyAfterStartIsNotDropped() async throws {
        let recorder = Recorder()
        let worker = FlushableWorker(interval: 10.0) { isFlushing in
            await recorder.add(isFlushing)
        }
        
        await worker.start()
        await worker.flush() // immediate flush should not be dropped
        try await Task.sleep(nanoseconds: 200_000_000) // allow processing
        await worker.stop()
        
        let flushes = await recorder.flushCount
        #expect(flushes == 1, "Immediate flush after start should be delivered exactly once")
        let ticks = await recorder.tickCount
        #expect(ticks == 0, "No ticks expected with very large interval")
    }
}
