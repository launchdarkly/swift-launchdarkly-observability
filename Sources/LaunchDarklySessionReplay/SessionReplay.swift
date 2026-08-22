import LaunchDarkly
import Foundation
import LaunchDarklyObservability
import OSLog
#if !LD_COCOAPODS
    import Common
#endif

public final class SessionReplay: Plugin {
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
        return .init(name: options.serviceName)
    }
    
    public func register(client: LaunchDarkly.LDClient, metadata: LaunchDarkly.EnvironmentMetadata) {
        install()
    }

    /// Builds the replay service against the installed observability pipeline and publishes it
    /// through ``LDReplay``.
    ///
    /// Registering this plugin with a ``LDClient`` calls this for you. Call it directly to run
    /// replay with no feature-flag SDK in the app. Observability must be installed first: replay
    /// records against its pipeline and shares its session.
    public func install() {
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
                imageCaptureService: imageCaptureService
            )
            LDReplay.shared.client = sessionReplayService
            self.sessionReplayService = sessionReplayService
            if options.isEnabled {
                Task { @MainActor in
                    sessionReplayService.isEnabled = true
                }
            }
        } catch {
            os_log("%{public}@", log: options.log, type: .error, "Session Replay Service initialization failed with error: \(error)")
        }
    }
    
    // Note: this plugin contributes no hooks. `Identify` and `Track` replay events are recorded
    // from Observability's single funnels via ObservabilityContext.identifies/.tracks, so they
    // cover both the LDClient paths and the manual LDObserve APIs without double-recording. The
    // native LDClient paths reach those funnels through ObservabilityHook.
    public func getHooks(metadata: EnvironmentMetadata) -> [any Hook] {
        return []
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

