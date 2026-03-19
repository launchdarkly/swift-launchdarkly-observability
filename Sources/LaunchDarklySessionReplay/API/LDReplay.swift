import Foundation
import LaunchDarkly

public final class LDReplay {
    public static var shared = LDReplay()

    /// Hook proxy for the C# / MAUI bridge. Set by the SessionReplay plugin during getHooks().
    public var hookProxy: SessionReplayHookProxy? {
        client.map { SessionReplayHookProxy(sessionReplayService: $0) }
    }

    var client: SessionReplayServicing?
    
    private init() {
        // privacy for singleton
    }
    
    @MainActor
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

