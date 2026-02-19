import UIKit
import LaunchDarkly
import LaunchDarklyObservability
import LaunchDarklySessionReplay


final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        let secrets = Bundle.main.infoDictionary!
        guard let mobileKey = secrets["mobileKey"] as? String, !mobileKey.isEmpty else {
            fatalError("Missing mobileKey in Info.plist. See Secrets.xcconfig.example.")
        }
        let otlpEndpoint = secrets["otlpEndpoint1"] as? String
        let backendUrl = secrets["backendUrl1"] as? String
        let config = { () -> LDConfig in
            var config = LDConfig(
                    mobileKey: mobileKey,
                    autoEnvAttributes: .enabled
                )
            config.plugins = [
                Observability(options: .init(
                    serviceName: "alexis-perf",
                    otlpEndpoint: otlpEndpoint,
                    backendUrl: backendUrl,
                    sessionBackgroundTimeout: 3,
                   )),
                SessionReplay(options: .init(
                    isEnabled: true,
                    privacy: .init(
                        maskTextInputs: true,
                        maskWebViews: false,
                        maskImages: false,
                        maskAccessibilityIdentifiers: ["email-field", "password-field", "card-brand-chip", "10"],
                    )
                ))
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
        return true
    }
}
