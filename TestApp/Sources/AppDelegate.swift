import UIKit
import LaunchDarkly
import LaunchDarklyObservability
import LaunchDarklySessionReplay


final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        //let mobileKey = "mob-48fd3788-eab7-4b72-b607-e41712049dbd"
        let mobileKey = "mob-a211d8b4-9f80-4170-ba05-0120566a7bd7" // Andrey Sessions stg production


        //let mobileKey = "mob-d6e200b8-4a13-4c47-8ceb-7eb1f1705070" // Spree demo app Alexis Perflet config = { () -> LDConfig in
        let config = { () -> LDConfig in
            var config = LDConfig(
                    mobileKey: mobileKey,
                    autoEnvAttributes: .enabled
                )
            config.plugins = [
                Observability(options: .init(
                    serviceName: "alexis-perf",
                    otlpEndpoint: "https://otel.observability.ld-stg.launchdarkly.com:4318",
                    backendUrl: "https://pub.observability.ld-stg.launchdarkly.com/",

//        let mobileKey = "mob-f2aca03d-4a84-4b9d-bc35-db20cbb4ca0a" // iOS Session Production
//        let config = { () -> LDConfig in
//            var config = LDConfig(
//                mobileKey: mobileKey,
//                autoEnvAttributes: .enabled
//            )
//            config.plugins = [
//                Observability(options: .init(
//                    serviceName: "i-os-sessions",
                    
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
