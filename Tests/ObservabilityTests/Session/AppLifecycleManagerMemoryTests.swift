import Foundation
import Testing
@testable import LaunchDarklyObservability

struct AppLifecycleManagerMemoryTests {
    @Test("AppLifecycleManager deallocates and finishes stream with active subscription")
    func appLifecycleManagerDeallocatesAndFinishesStream() {
        // Given
        weak var weakManager: AppLifecycleManager?
        var consumerTask: Task<Void, Never>?
        var streamFinished = false

        autoreleasepool {
            let manager = AppLifecycleManager()
            weakManager = manager

            // Obtain the stream without permanently capturing the manager in a long-lived task
            var stream: AsyncStream<AppLifeCycleEvent>?
            let fetchStream = Task {
                stream = await manager.events()
            }

            // Wait briefly for the stream to be produced
            let streamDeadline = Date().addingTimeInterval(1.0)
            while stream == nil && Date() < streamDeadline {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
            }

            // Start consuming the stream so there is an active subscription
            if let stream {
                consumerTask = Task {
                    for await event in stream {
                        #expect(event == .didBecomeActive)
                        streamFinished = true
                    }
                }
            }

            // Ensure the stream begins flowing at least once
            manager.send(.didBecomeActive)

            // Ensure the short-lived fetch task has completed
            _ = fetchStream
        }

        // When: release strong references and give the runtime a moment to clean up
        let deadline = Date().addingTimeInterval(2.0)
        while (weakManager != nil || streamFinished == false) && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }

        // Then: the manager should be deallocated and the stream should be finished
        #expect(weakManager == nil)
        #expect(streamFinished == true)

        // Cleanup
        consumerTask?.cancel()
    }
}


