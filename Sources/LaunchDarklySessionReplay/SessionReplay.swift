import LaunchDarkly
import Foundation
import LaunchDarklyObservability
import OSLog
#if !LD_COCOAPODS
    import Common
#endif

public final class SessionReplay: Plugin {
    /// One hook per environment, keyed by mobile key. Only the primary environment's hook is given a
    /// delegate, so the hooks of `LDConfig.secondaryMobileKeys` clients record nothing.
    let sessionReplayHooks = AtomicDictionary<String, SessionReplayHook>()
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
        // Secondary environments are registered too; see `ObservabilityPlugin.register`.
        guard LaunchDarkly.LDClient.get() === client else { return }
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
            sessionReplayHooks[metadata.credential]?.delegate = sessionReplayService
            if options.isEnabled {
                Task { @MainActor in
                    sessionReplayService.isEnabled = true
                }
            }
        } catch {
            os_log("%{public}@", log: options.log, type: .error, "Session Replay Service initialization failed with error: \(error)")
        }
    }
    
    // Note: this hook is intentionally not wrapped in DedupingHook. Deduplication only
    // suppresses evaluation stages, and SessionReplayHook implements identify only, which
    // DedupingHook always forwards. Evaluation spans come from ObservabilityHook, which is
    // wrapped there instead.
    public func getHooks(metadata: EnvironmentMetadata) -> [any Hook] {
        let hook = SessionReplayHook()
        sessionReplayHooks.setValue(hook, forKey: metadata.credential)
        return [hook]
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

    /// Starts exporting queued replay events now. See ``LDReplay/flush()``.
    public func flush() async {
        await sessionReplayService?.flush()
    }
}

