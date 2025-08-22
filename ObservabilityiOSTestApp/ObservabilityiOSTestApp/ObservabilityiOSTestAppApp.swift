import SwiftUI
import LaunchDarkly
import Plugin

let mobileKey = "mob-dbe6f0ac-80ce-4903-bf20-431c2e7aeae1"
let config = { () -> LDConfig in
    var config = LDConfig(
        mobileKey: mobileKey,
        autoEnvAttributes: .enabled
    )
    config.plugins = [
        Observability()
    ]
    return config
}()

let context = { () -> LDContext in
    var contextBuilder = LDContextBuilder(
        key: "12345"
    )
    contextBuilder.kind("user")
    do {
        return try contextBuilder.build().get()
    } catch {
        abort()
    }
}()

final class AppDelegate: NSObject, UIApplicationDelegate {
    lazy var once: Void = {
        let completion = { (timedOut: Bool) -> Void in
            if timedOut {
                // Client may not have the most recent flags for the configured context
            } else {
                // Client has received flags for the configured context
            }
        }
        LDClient.start(
            config: config,
            context: context,
            startWaitSeconds: 5.0,
            completion: completion
        )
    }()
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        print(once)
        return true
    }
}

@main
struct ObservabilityiOSTestAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
