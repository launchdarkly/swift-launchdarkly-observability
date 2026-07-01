import LaunchDarkly
import Foundation
import LaunchDarklyObservability
import OSLog
#if !LD_COCOAPODS
    import Common
#endif

public final class SessionReplay: Plugin {
    let sessionReplayHook = SessionReplayHook()
    let options: SessionReplayOptions
    let imageCaptureService: ImageCaptureServicing?
    var sessionReplayService: SessionReplayService?
    var observabilityContext: ObservabilityContext?
    
    public init(
        options: SessionReplayOptions,
        imageCaptureService: ImageCaptureServicing? = nil
    ) {
        self.options = options
        self.imageCaptureService = imageCaptureService
    }
    
    public func getMetadata() -> LaunchDarkly.PluginMetadata {
        return .init(name: "session-replay-service") // not used
    }
    
    public func register(client: LaunchDarkly.LDClient, metadata: LaunchDarkly.EnvironmentMetadata) {
        guard let context = LDObserve.shared.context else {
            os_log("%{public}@", log: options.log, type: .error, "Session Replay Service could not find Observability Service")
            return
        }
        
        observabilityContext = context
        
        do {
            guard LDReplay.shared.client == nil else {
                throw PluginError.sessionReplayInstanceAlreadyExist
            }
           
            let sessionReplayService = try SessionReplayService(
                observabilityContext: context,
                sessonReplayOptions: options,
                metadata: metadata,
                imageCaptureService: imageCaptureService
            )
            LDReplay.shared.client = sessionReplayService
            self.sessionReplayService = sessionReplayService
            sessionReplayHook.delegate = sessionReplayService
            if options.isEnabled {
                Task { @MainActor in
                    sessionReplayService.isEnabled = true
                }
            }
        } catch {
            os_log("%{public}@", log: options.log, type: .error, "Session Replay Service initialization failed with error: \(error)")
        }
    }
    
    public func getHooks(metadata: EnvironmentMetadata) -> [any Hook] {
        return [sessionReplayHook]
    }
    
    /// Starts Session Replay. Set `ignoreSampling` to `true` to force start for debugging.
    @MainActor
    @discardableResult
    public func start(ignoreSampling: Bool = false) -> SessionReplayStartResult {
        sessionReplayService?.start(ignoreSampling: ignoreSampling) ?? .unavailable
    }
    
    @MainActor
    public func stop() {
        sessionReplayService?.stop()
    }
}

