#if canImport(UIKit)
import Foundation
import UIKit
import Testing
@testable import LaunchDarklyObservability

struct LaunchTrackerTests {
    @Test
    func coldLaunch() {
        let coldStart = TimeInterval(0)
        let sut = LaunchTracker(
            initialState: .init(
                coldLaunchStart: coldStart,
                hasRenderedFirstFrame: false
            )
        )
        /*
         UIScene.willConnectNotification
         UIScene.willEnterForegroundNotification
         UIScene.willConnectNotification
         UIScene.willEnterForegroundNotification
         UIScene.didActivateNotification
         */
        #expect(sut.state.hasRenderedFirstFrame == false)
        #expect(sut.state.coldLaunchStart == coldStart)
        
        // post willConnectNotification notification
        NotificationCenter.default.post(name: UIScene.willConnectNotification, object: nil)
    }
}
#endif
