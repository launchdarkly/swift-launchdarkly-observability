import Foundation
import LaunchDarkly

public final class LDReplay {
    public static var shared = LDReplay()

    var client: SessionReplayServicing?
    
    private init() {
        // privacy for singleton
    }
    
    public var isEnabled: Bool {
        get { client?.isEnabled ?? false }
        set { client?.isEnabled = newValue }
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

