/*
import Testing
import UIKit
@testable import LaunchDarklyObservability


struct SessionManagerTests {
    @Test
    func foregroundWhenTimeOutHandling() async throws {
        let sut = SessionManager(options: .init(sessionTimeout: 0.5))
        await sut.start()
        let oldContext = await sut.sessionContext
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        try await wait(for: 1.0)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        let newContext = await sut.sessionContext
        #expect(newContext.sessionId != oldContext.sessionId)
    }
    
    func wait(for time: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(time))
    }
}
*/
