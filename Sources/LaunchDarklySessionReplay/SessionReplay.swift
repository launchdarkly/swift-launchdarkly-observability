import LaunchDarkly
import Foundation
import Observability
import OSLog
import SessionReplay

public final class SessionReplay: Plugin {
    private let options: SessionReplayOptions
    private var sessionReplayService: SessionReplayService?
    
    public init(options: SessionReplayOptions) {
        self.options = options
    }
    
    public func getMetadata() -> LaunchDarkly.PluginMetadata {
        return .init(name: options.serviceName)
    }
    
    public func register(client: LaunchDarkly.LDClient, metadata: LaunchDarkly.EnvironmentMetadata) {
        guard options.isEnabled,
              let context = client.observabilityService?.context else {
            os_log("%{public}@", log: options.log, type: .error, "Session Replay Service could not find Observability Service")
            return
        }
        
        do {
            sessionReplayService = try SessionReplayService(context: context,
                                                            sessonReplayOptions: options)
        } catch {
            os_log("%{public}@", log: options.log, type: .error, "Session Replay Service initialization failed with error: \(error)")
        }
    }
}
