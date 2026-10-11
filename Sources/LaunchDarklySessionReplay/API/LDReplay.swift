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

    /// Starts exporting queued replay events now instead of at the next export interval, for
    /// example before the app tears the SDK down. Returns once the export pass is scheduled,
    /// without waiting for uploads to finish. No-op before Session Replay is initialized.
    public func flush() async {
        await client?.flush()
    }
}

