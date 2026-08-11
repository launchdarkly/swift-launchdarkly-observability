import UIKit
import LaunchDarkly
// The only SDK import in this app. `LaunchDarklyObservability` is deliberately absent, so the
// app fails to build if anything here needs the instrumentation package.
import LaunchDarklyOtel

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard let secrets = Bundle.main.infoDictionary,
              let mobileKey = secrets["mobileKey"] as? String, !mobileKey.isEmpty else {
            fatalError("Missing mobileKey in Info.plist. See TestAppShared/Secrets.xcconfig.example.")
        }

        var config = LDConfig(mobileKey: mobileKey, autoEnvAttributes: .enabled)
        config.plugins = [
            Otel(options: .init(
                serviceName: "observability-ios-otel-test-app",
                otlpEndpoint: secrets["otlpEndpoint"] as? String,
                backendUrl: secrets["backendUrl"] as? String,
                resourceAttributes: ["test-options-attribute": .string("ios-otel-test-app")],
                // Short enough to rotate the session by backgrounding the app for a few seconds.
                sessionBackgroundTimeout: 3
            ))
        ]

        LDClient.start(config: config, context: Self.context(), startWaitSeconds: 5.0) { timedOut in
            if timedOut {
                print("LDClient started without the most recent flags")
            }
        }

        return true
    }

    private static func context() -> LDContext {
        var builder = LDContextBuilder(key: "12345")
        builder.kind("user")
        do {
            return try builder.build().get()
        } catch {
            fatalError("Could not build the LaunchDarkly context: \(error)")
        }
    }
}
