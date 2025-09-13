import SwiftUI

@main
struct ExampleAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var browser = Browser()
    
    
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $browser.path) {
                ContentView()
                    .navigationDestination(for: Path.self) { path in
                        switch path {
                        case .home:
                            ContentView()
                        case .manualInstrumentation:
                            InstrumentationView()
                        case .automaticInstrumentation:
                            NetworkRequestView()
                        case .evaluation:
                            FeatureFlagView()
                        }
                    }
            }
            .environment(browser)
        }
    }
}
