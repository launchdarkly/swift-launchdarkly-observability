import OSLog
@_exported import LaunchDarkly
#if !LD_COCOAPODS
@_exported import LaunchDarklyOtel
#endif

/// The full LaunchDarkly observability plugin: the OpenTelemetry pipeline plus automatic
/// instrumentation — URLSession tracing, tap and screen capture, resource sampling and
/// crash reporting.
///
/// The instrumentation installs process-wide hooks (method swizzling, crash handlers), so
/// this plugin can collide with another observability SDK doing the same. Use `Otel` from
/// the `LaunchDarklyOtel` product for a pipeline that records only what the app asks it to.
public final class Observability: ObservabilityPlugin {
    static let SDK_NAME = "swift-launchdarkly-observability"

    public init(options: ObservabilityOptions) {
        if case .provider(let provider) = options.crashReporting.source {
            // Installed before anything else so a crash during SDK startup is captured.
            do {
                try provider.install(options: options)
            } catch {
                os_log("%{public}@", log: options.log, type: .error, "Observability crash reporting service initialization failed with error: \(error)")
            }
        }
        super.init(
            options: options,
            distroName: Observability.SDK_NAME,
            instrumenting: DefaultInstrumentation()
        )
    }
}

extension ObservabilityContext {
    /// The touch-capture pipeline, downcast to the concrete manager owned by this package.
    /// `nil` when the pipeline was configured without automatic instrumentation.
    public var userInteractions: UserInteractionManager? {
        userInteractionManager as? UserInteractionManager
    }
}
