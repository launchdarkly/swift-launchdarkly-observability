import Foundation
import LaunchDarkly

public final class LDReplay {
    public static var shared = LDReplay()
    
    @MainActor
    var client: SessionReplayServicing?
    
    private init() {
        // privacy for singleton
    }
    
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

