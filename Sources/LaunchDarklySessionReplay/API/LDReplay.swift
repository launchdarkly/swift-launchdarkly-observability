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

    /// Starts or stops Session Replay. Setting this to `true` applies sampling.
    @MainActor
    public var isEnabled: Bool {
        get { client?.isEnabled ?? false }
        set { client?.isEnabled = newValue }
    }

    /// Whether Session Replay is currently running.
    @MainActor
    public var isRunning: Bool {
        client?.isRunning ?? false
    }
    
    /// Starts Session Replay. Set `ignoreSampling` to `true` to force start for debugging.
    @MainActor
    @discardableResult
    public func start(ignoreSampling: Bool = false) -> SessionReplayStartResult {
        client?.start(ignoreSampling: ignoreSampling) ?? .unavailable
    }
    
    @MainActor
    public func stop() {
        client?.stop()
    }
}

