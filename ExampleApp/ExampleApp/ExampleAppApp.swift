import SwiftUI

@main
struct ExampleAppApp: App {
    @State private var browser = Browser()
    @State private var client = Client()
    
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
            .onAppear {
                client.start()
            }
        }
    }
}
