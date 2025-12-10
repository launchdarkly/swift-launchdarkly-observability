import LaunchDarkly
import Foundation
import LaunchDarklyObservability
import OSLog

public final class SessionReplay: Plugin {
    let options: SessionReplayOptions
    var sessionReplayService: SessionReplayService?
    var observabilityContext: ObservabilityContext?
    
    public init(options: SessionReplayOptions) {
        self.options = options
    }
    
    public func getMetadata() -> LaunchDarkly.PluginMetadata {
        return .init(name: options.serviceName)
    }
    
    public func register(client: LaunchDarkly.LDClient, metadata: LaunchDarkly.EnvironmentMetadata) {
        guard options.isEnabled,
              let context = LDObserve.shared.context else {
            os_log("%{public}@", log: options.log, type: .error, "Session Replay Service could not find Observability Service")
            return
        }
        
        observabilityContext = context

        do {
            sessionReplayService = try SessionReplayService(context: context,
                                                            sessonReplayOptions: options,
                                                            metadata: metadata)
        } catch {
            os_log("%{public}@", log: options.log, type: .error, "Session Replay Service initialization failed with error: \(error)")
        }
    }
    
    public func getHooks(metadata: EnvironmentMetadata) -> [any Hook] {
        [SessionReplayHook(plugin: self)]
    }
}
