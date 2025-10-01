import UIKit
import LaunchDarkly
import LaunchDarklyObservability

let mobileKey = "mob-48fd3788-eab7-4b72-b607-e41712049dbd"
let config = { () -> LDConfig in
    var config = LDConfig(
        mobileKey: mobileKey,
        autoEnvAttributes: .enabled
    )
    config.plugins = [
        Observability(
            options: .init(
                serviceName: "MyApp (ExampleApp)",
//                otlpEndpoint: "http://localhost:4318",
                sessionBackgroundTimeout: 3,
                isDebug: true,
                disableLogs: false,
                disableTraces: false,
                disableMetrics: false
            )
        )
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
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        LDClient.start(
            config: config,
            context: context,
            startWaitSeconds: 5.0,
            completion: { (timedOut: Bool) -> Void in
                if timedOut {
                    // Client may not have the most recent flags for the configured context
                } else {
                    // Client has received flags for the configured context
                }
            }
        )
        return true
    }
}
