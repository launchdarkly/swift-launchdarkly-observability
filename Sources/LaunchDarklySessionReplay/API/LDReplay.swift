import Foundation
import LaunchDarkly

public final class LDReplay: AnyObject {
    public static var shared = LDReplay()

    var client: SessionReplayServicing?
        
    public func start() {
        Task { @MainActor in
            client?.start()
        }
    }
    
    public func stop() {
        Task { @MainActor in
            client?.stop()
        }
    }
}

