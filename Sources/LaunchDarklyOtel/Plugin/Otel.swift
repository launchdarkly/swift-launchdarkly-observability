import Foundation

/// The OpenTelemetry-only LaunchDarkly plugin.
///
/// Records exactly what the app asks it to through ``LDObserve`` — logs, spans, metrics,
/// errors and `track` events — and exports them over OTLP. It installs nothing into the
/// host app: no URLSession or UIKit swizzling, no crash handlers, no resource sampling.
/// That makes it safe to run alongside another observability SDK, which
/// `LaunchDarklyObservability` is not, since the two would compete for the same hooks.
///
/// Flag evaluation, identify and track hooks still work, and every signal is stamped with
/// the current session.
///
/// ```swift
/// let config = LDConfig(mobileKey: mobileKey, autoEnvAttributes: .enabled)
/// config.plugins = [Otel(options: ObservabilityOptions())]
/// ```
///
/// Use `Observability` from the `LaunchDarklyObservability` product instead when you want
/// automatic instrumentation and crash reporting.
public final class Otel: ObservabilityPlugin {
    static let SDK_NAME = "swift-launchdarkly-otel"

    /// - Parameter options: Pipeline configuration. The `instrumentation` and
    ///   `crashReporting` sections are ignored: this plugin installs no instrumentation.
    public init(options: ObservabilityOptions) {
        super.init(options: options, distroName: Otel.SDK_NAME, instrumenting: nil)
    }
}
