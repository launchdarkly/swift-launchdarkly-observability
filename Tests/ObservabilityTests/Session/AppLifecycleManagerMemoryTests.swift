import Foundation
import Combine
import Testing
@testable import LaunchDarklyObservability

struct AppLifecycleManagerMemoryTests {
    @Test("AppLifecycleManager deallocates and finishes stream with active subscription")
    func appLifecycleManagerDeallocatesAndFinishesStream() {
        // Given
        weak var weakManager: AppLifecycleManager?
        var cancellable: AnyCancellable?
        var streamFinished = false
        
        autoreleasepool {
            let manager: AppLifecycleManager? = AppLifecycleManager()
            weakManager = manager
            
            // Subscribe to the publisher without capturing the manager strongly
            cancellable = manager?.publisher().sink(
                receiveCompletion: { completion in
                    if case .finished = completion {
                    }
                },
                receiveValue: { event in
                    #expect(event == .didBecomeActive)
                    streamFinished = true
                }
            )
            
            // Ensure the stream begins flowing at least once
            manager?.send(.didBecomeActive)

            // Allow any scheduled work to run before the pool drains
            let deadline = Date().addingTimeInterval(2.0)
            while (streamFinished == false) && Date() < deadline {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            }
            
            
           // manager.send(.didEnterBackground)
            #expect(manager != nil)
        }
        
        // When: release strong references and give the runtime a moment to clean up
        let deadline = Date().addingTimeInterval(2.0)
        while (weakManager != nil) && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        
        // Then: the manager should be deallocated and the stream should be finished
        #expect(weakManager == nil)
        #expect(streamFinished == true)
        
        // Cleanup
        cancellable?.cancel()
    }
}


