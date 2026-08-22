import LaunchDarkly
import LaunchDarklyObservability
#if !LD_COCOAPODS
import LaunchDarklyOtel
#endif

public extension LDObserve {

    /// Sets up observability and Session Replay with no feature-flag SDK involved.
    ///
    /// Telemetry and replays are exported for the environment [mobileKey] identifies. No context is
    /// identified: call ``LDObserve/identify(key:attributes:)`` once the user is known, so the
    /// session is attributed to them rather than recorded as `unknown`.
    ///
    /// - Parameters:
    ///   - mobileKey: Credential for the LaunchDarkly environment telemetry is sent to.
    ///   - observability: Pipeline and instrumentation configuration.
    ///   - replay: Session Replay configuration.
    ///   - imageCaptureService: Capture implementation for Session Replay. `nil` uses the built-in
    ///     screenshot capture.
    ///   - customSessionId: Session id to adopt instead of generating one, so this instance can
    ///     share a single `session.id` with another LaunchDarkly SDK on the device.
    static func configure(
        mobileKey: String,
        observability: ObservabilityOptions = ObservabilityOptions(),
        replay: SessionReplayOptions,
        imageCaptureService: ImageCaptureServicing? = nil,
        customSessionId: String? = nil
    ) {
        Observability(options: observability, customSessionId: customSessionId)
            .install(mobileKey: mobileKey)
        SessionReplay(options: replay, imageCaptureService: imageCaptureService).install()
    }

    /// Sets up observability and Session Replay against an already initialized ``LDClient``, so flag
    /// evaluations, identify calls and track calls made through that client are instrumented and
    /// recorded onto the replay.
    ///
    /// - Parameters:
    ///   - ldClient: The initialized client to instrument.
    ///   - context: The context `ldClient` was started with. The client identifies it before this
    ///     call can attach a hook, so it is identified here instead; without it the session would
    ///     be recorded as `unknown` until the app's next `identify`.
    ///   - observability: Pipeline and instrumentation configuration.
    ///   - replay: Session Replay configuration.
    ///   - imageCaptureService: Capture implementation for Session Replay. `nil` uses the built-in
    ///     screenshot capture.
    ///   - customSessionId: Session id to adopt instead of generating one, so this instance can
    ///     share a single `session.id` with another LaunchDarkly SDK on the device.
    static func configure(
        ldClient: LDClient,
        context: LDContext,
        observability: ObservabilityOptions = ObservabilityOptions(),
        replay: SessionReplayOptions,
        imageCaptureService: ImageCaptureServicing? = nil,
        customSessionId: String? = nil
    ) {
        ldClient.registerPlugin(Observability(options: observability, customSessionId: customSessionId))
        ldClient.registerPlugin(SessionReplay(options: replay, imageCaptureService: imageCaptureService))
        // Seeded only once replay is registered: the identify is broadcast, not buffered, so a
        // replay service that does not exist yet would never see it.
        LDObserve.shared.identify(seeding: context)
    }
}

private extension LDObserve {
    /// Records the identity `LDClient` was started with, which no `afterIdentify` hook can observe.
    func identify(seeding context: LDContext) {
        var contextKeys = [String: String]()
        for (kind, key) in context.contextKeys() { contextKeys[kind] = key }
        identify(contextKeys: contextKeys, canonicalKey: context.fullyQualifiedKey())
    }
}
