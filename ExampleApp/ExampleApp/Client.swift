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
                    logsApiLevel: .info,
                    tracesApi: .enabled,
                    metricsApi: .enabled,
                    crashReporting: .enabled,
                    instrumentation: .init(
                        urlSession: .enabled,
                        userTaps: .enabled,
                        memory: .enabled,
                        memoryWarnings: .enabled,
                        cpu: .disabled,
                        launchTimes: .enabled
                    ),
                    sessionIdProvider: CustomSessionIdProvider()
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
    
    init() {
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

actor CustomSessionIdProvider: SessionIdProvider {
    func generateSessionId() async throws -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "hello_world_user_\(timestamp)"
    }
}
