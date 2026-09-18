#if !LD_COCOAPODS
import LaunchDarklyOtel
#endif
import LaunchDarkly

public extension LDObserve {

    /// Sets up observability with no feature-flag SDK involved.
    ///
    /// Telemetry recorded through ``LDObserve`` is exported for the environment [mobileKey]
    /// identifies. Nothing is evaluated, so no flag spans are produced and
    /// `launchdarkly.sdk.version` is omitted. No context is identified either: call
    /// ``LDObserve/identify(key:attributes:)`` once the user is known, so telemetry is attributed
    /// to them.
    ///
    /// - Parameters:
    ///   - mobileKey: Credential for the LaunchDarkly environment telemetry is sent to.
    ///   - observability: Pipeline and instrumentation configuration.
    ///   - customSessionId: Session id to adopt instead of generating one, so this instance can
    ///     share a single `session.id` with another LaunchDarkly SDK on the device.
    static func configure(
        mobileKey: String,
        observability: ObservabilityOptions = ObservabilityOptions(),
        customSessionId: String? = nil
    ) {
        Observability(options: observability, customSessionId: customSessionId)
            .install(mobileKey: mobileKey)
    }

    /// Sets up observability against an already initialized ``LDClient``, so flag evaluations,
    /// identify calls and track calls made through that client are instrumented.
    ///
    /// This takes the same arguments as ``configure(mobileKey:observability:customSessionId:)``,
    /// differing only in that the environment comes from `ldClient` rather than a mobile key.
    /// Prefer it over passing ``Observability`` to `LDConfig.plugins`: the client's configuration
    /// is left alone, and observability is set up the same way whether or not the flagging SDK is
    /// involved.
    ///
    /// - Parameters:
    ///   - ldClient: The initialized client to instrument.
    ///   - context: The context `ldClient` was started with. The client identifies it before this
    ///     call can attach a hook, so it is identified here instead; without it, telemetry would
    ///     stay unattributed until the app's next `identify`.
    ///   - observability: Pipeline and instrumentation configuration.
    ///   - customSessionId: Session id to adopt instead of generating one, so this instance can
    ///     share a single `session.id` with another LaunchDarkly SDK on the device.
    static func configure(
        ldClient: LDClient,
        context: LDContext,
        observability: ObservabilityOptions = ObservabilityOptions(),
        customSessionId: String? = nil
    ) {
        ldClient.registerPlugin(Observability(options: observability, customSessionId: customSessionId))
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
