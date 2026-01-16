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
        guard let context = LDObserve.shared.context else {
            os_log("%{public}@", log: options.log, type: .error, "Session Replay Service could not find Observability Service")
            return
        }
                
        observabilityContext = context

        do {
            sessionReplayService = try SessionReplayService(observabilityContext: context,
                                                            sessonReplayOptions: options,
                                                            metadata: metadata)
            if options.isEnabled {
                sessionReplayService?.start()
            }
        } catch {
            os_log("%{public}@", log: options.log, type: .error, "Session Replay Service initialization failed with error: \(error)")
        }
    }
    
    public func getHooks(metadata: EnvironmentMetadata) -> [any Hook] {
        [SessionReplayHook(plugin: self)]
    }
    
    public func start() {
        sessionReplayService?.start()
    }
    
    public func stop() {
        sessionReplayService?.stop()
    }
}
