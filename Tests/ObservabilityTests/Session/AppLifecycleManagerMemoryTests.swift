import Foundation
import Combine
import Testing
@testable import LaunchDarklyObservability

struct AppLifecycleManagerMemoryTests {
    @Test("AppLifecycleManager deallocates and finishes stream with active subscription")
    func appLifecycleManagerDeallocatesAndFinishesStream() {
        weak var weakManager: AppLifecycleManager?
        var receivedActivated = false
        var cancellable: AnyCancellable?

        autoreleasepool {
            let manager = AppLifecycleManager()
            weakManager = manager

            cancellable = manager.publisher().sink(
                receiveCompletion: { _ in },
                receiveValue: { event in
                    if event == .didBecomeActive { receivedActivated = true }
                }
            )

            manager.send(.didBecomeActive)
        }

        #expect(receivedActivated)
        #expect(weakManager == nil)
        cancellable?.cancel()
    }
}


