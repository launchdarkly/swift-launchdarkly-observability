import UIKit
import LaunchDarkly
import LaunchDarklyObservability

let config = { () -> LDConfig in
    var config = LDConfig(
        mobileKey: Env.mobileKey,
        autoEnvAttributes: .enabled
    )
    config.plugins = [
        Observability(
            options: .init(
                otlpEndpoint: Env.otelHost,
                sessionBackgroundTimeout: 3,
                isDebug: true,
                logs: .enabled,
                traces: .enabled,
                metrics: .enabled
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

