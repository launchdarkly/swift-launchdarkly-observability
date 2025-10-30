import UIKit
import LaunchDarklyObservability

struct Client {
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
                    metrics: .enabled,
                    crashReporting: .disabled,
                    autoInstrumentation: [.urlSession, .userTaps, .memory, .cpu, .memoryWarnings]
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
    
    func start() {
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
    }
}
