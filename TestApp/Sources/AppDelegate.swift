import UIKit
import LaunchDarkly
import LaunchDarklyObservability
import LaunchDarklySessionReplay


final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {        
        guard let secrets = Bundle.main.infoDictionary,
              let mobileKey = secrets["mobileKey"] as? String, !mobileKey.isEmpty else {
            fatalError("Missing mobileKey in Info.plist. See Secrets.xcconfig.example.")
        }
        let otlpEndpoint = secrets["otlpEndpoint"] as? String
        let backendUrl = secrets["backendUrl"] as? String
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
        
        flagEvaluation()

        return true
    }
    
  
    lazy var client = LDClient.get()!
    let flagKey = "feature1"
    lazy var flagObserverOwner = flagKey as LDObserverOwner
  
    func flagEvaluation() {
        let key = flagKey
        let value = client.boolVariation(forKey: key, defaultValue: false)
        print("sync \(key) value=", value)
        client.observe(keys: [key], owner: flagObserverOwner, handler: { changedFlags in
            if let value = changedFlags[key] {
                print("observe \(key) value=", value)
            }
        })
    }
}
