import Testing
import Combine
import OSLog
@testable import LaunchDarklyObservability

private final class TestLifecycleManager: AppLifecycleManaging {
    private let subject = PassthroughSubject<AppLifeCycleEvent, Never>()

    func publisher() -> AnyPublisher<AppLifeCycleEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    func send(_ event: AppLifeCycleEvent) {
        subject.send(event)
    }

    func finish() {
        subject.send(completion: .finished)
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
            
            // Allow any scheduled work to run before the pool drains
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
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


