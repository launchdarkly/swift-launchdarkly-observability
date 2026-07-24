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

    /// Suspends until `condition` holds, giving up after `polls` attempts.
    ///
    /// The give-up budget is counted in polls rather than wall-clock time on purpose. A deadline
    /// keeps running while the test is not running, so on a loaded CI machine - where the
    /// cooperative pool can stall for seconds at a time - it can expire without the worker or the
    /// poll ever being scheduled, and the test then reports as missing work that was simply never
    /// given a chance to run. A poll budget only shrinks when the test actually gets scheduled.
    private func waitUntil(polls: Int = 400, _ condition: () async -> Bool) async throws {
        for _ in 0 ..< polls {
            if await condition() { return }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
    }

    /// Time given to work that is expected *not* to happen, so the assertion that it didn't happen
    /// is meaningful.
    private let settleTime: UInt64 = 200_000_000

    @Test
    func ticksOccurOnInterval() async throws {
        let recorder = Recorder()
        let worker = FlushableWorker(interval: 0.025) { isFlushing in
            await recorder.add(isFlushing)
        }
        
        await worker.start()
        
        try await waitUntil { await recorder.tickCount >= 1 }
        
        await worker.stop()
        
        let ticks = await recorder.tickCount
        #expect(ticks >= 1, "Expected at least one tick execution")
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
        await worker.flush()
        try await waitUntil { await recorder.flushCount >= 1 }
        try await Task.sleep(nanoseconds: settleTime) // let an unexpected second flush surface
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
        try await waitUntil { await recorder.flushCount >= 1 }
        try await Task.sleep(nanoseconds: settleTime) // let a non-coalesced second flush surface
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
        
        let began = Date()
        await worker.start()
        try await Task.sleep(nanoseconds: NSEC_PER_SEC / 2)
        await worker.start() // should be a no-op due to guard
        try await Task.sleep(nanoseconds: NSEC_PER_SEC / 2)
        await worker.stop()
        let observed = Date().timeIntervalSince(began)
        
        // One ticking loop can emit at most one tick per interval over the observed window, so a
        // second loop would roughly double the count. The bound is derived from the measured
        // window rather than hard-coded because sleeps overshoot on a loaded machine, and a
        // hard-coded bound turns that overshoot into a spurious failure.
        let singleLoopTicks = Int(observed / interval) + 2
        let ticks = await recorder.tickCount
        #expect(ticks <= singleLoopTicks,
                "Idempotent start should not create multiple ticking loops (\(ticks) ticks in \(observed)s)")
    }
    
    @Test
    func stopCancelsFurtherEmissions() async throws {
        let recorder = Recorder()
        let worker = FlushableWorker(interval: 0.05) { isFlushing in
            await recorder.add(isFlushing)
        }
        
        await worker.start()
        try await waitUntil { await recorder.tickCount >= 1 }
        await worker.stop()
        
        // Sample the baseline only after work that was already in flight when stop() landed has
        // had a chance to record: cancelling the processing task does not interrupt a unit of work
        // that has already started, and counting such a tick as post-stop would be a false alarm.
        try await Task.sleep(nanoseconds: settleTime)
        let ticksAtStop = await recorder.tickCount
        
        // After stop, there should be no further events
        try await Task.sleep(nanoseconds: settleTime)
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
        try await waitUntil { await recorder.flushCount >= 1 }
        try await Task.sleep(nanoseconds: settleTime) // let a duplicate flush surface
        await worker.stop()
        
        let flushes = await recorder.flushCount
        #expect(flushes == 1, "Immediate flush after start should be delivered exactly once")
        let ticks = await recorder.tickCount
        #expect(ticks == 0, "No ticks expected with very large interval")
    }
}
