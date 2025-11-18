import Testing
import OSLog
@testable import LaunchDarklyObservability

private final class TestLifecycleManager: AppLifecycleManaging {
    private var continuation: AsyncStream<AppLifeCycleEvent>.Continuation?

    func events() async -> AsyncStream<AppLifeCycleEvent> {
        AsyncStream<AppLifeCycleEvent> { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                self?.continuation = nil
            }
        }
    }

    func send(_ event: AppLifeCycleEvent) {
        continuation?.yield(event)
    }

    func finish() {
        continuation?.finish()
    }
}

struct SessionManagerMemoryTests {
    @Test("SessionManager deallocates after release (no memory leak)")
    func sessionManagerDeallocatesAfterRelease() {
        // Given
        let lifecycle = TestLifecycleManager()
        let options = SessionOptions(timeout: 0.1, isDebug: false, log: OSLog(subsystem: "test", category: "SessionManagerMemoryTests"))

        weak var weakManager: SessionManager?

        autoreleasepool {
            let manager = SessionManager(options: options, appLifecycleManager: lifecycle)
            weakManager = manager

            // Drive at least one event through the loop to ensure the Task starts iterating
            lifecycle.send(.didBecomeActive)
        }

        // When: release strong references and give the runtime a moment to clean up
        let deadline = Date().addingTimeInterval(2.0)
        while weakManager != nil && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }

        // Then
        #expect(weakManager == nil)
    }
}


