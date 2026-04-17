import SwiftUI

@main
struct ExampleAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        WindowGroup {
            #if os(tvOS)
            TVMainMenuView()
            #else
            MainMenuView()
            #endif
        }
    }
}
