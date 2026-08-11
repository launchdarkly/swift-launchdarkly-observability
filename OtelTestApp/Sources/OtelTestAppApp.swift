import SwiftUI

@main
struct OtelTestAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            OtelMenuView()
        }
    }
}
