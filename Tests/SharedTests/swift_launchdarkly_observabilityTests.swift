import Testing
import Shared

@Test
func appLifeCycleObserver() async throws {
    
    Task {
        for await event in NotificationCenter.default.notifications(for: UIApplication.test) {
            print("event: \(event.rawValue)")
            #expect(event == UIApplication.test)
        }
    }
    
    NotificationCenter.default.post(name: UIApplication.test, object: nil)
    try await Task.sleep(for: .seconds(0.5))
    NotificationCenter.default.post(name: UIApplication.test, object: nil)
    try await Task.sleep(for: .seconds(0.5))
    NotificationCenter.default.post(name: UIApplication.test, object: nil)
    try await Task.sleep(for: .seconds(0.5))
    NotificationCenter.default.post(name: UIApplication.test, object: nil)
    try await Task.sleep(for: .seconds(0.5))
}

public extension UIApplication {
    nonisolated static let test: Notification.Name = .init("test")
}
