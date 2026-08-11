import Foundation

/// Supplies the automatic instrumentation for an ``ObservabilityService``.
///
/// This is the seam between the core OTel pipeline and the instrumentation that hooks into
/// the host app — URLSession and UIKit swizzling, crash handlers, resource sampling. The
/// pipeline itself installs none of it, which is what lets `LaunchDarklyOtel` be used
/// alongside another observability SDK without the two fighting over the same hooks.
///
/// Every factory may return `nil`/`[]`; the pipeline degrades to manual instrumentation only.
public protocol ObservabilityInstrumenting: AnyObject {
    /// Resolved before the pipeline is built so the signal can be handed to
    /// ``ObservabilityContext`` as an immutable setup value (Session Replay reads it at
    /// construction to place the `Launch` breadcrumb).
    /// - Parameter appStartEndUptime: uptime marking the end of the startup window, captured
    ///   at the earliest SDK entry point so it excludes the SDK's own initialization.
    func resolveAppLaunchSignal(appStartEndUptime: TimeInterval) -> AppLaunchSignal?

    /// Built during installation, before ``ObservabilityService/start()``, because
    /// ``ObservabilityContext`` carries it to Session Replay. Must not install its capture
    /// hook until started.
    func makeUserInteractionManager(runtime: ObservabilityRuntime) -> UserInteractionManaging?

    /// Built when the service starts. Returned instrumentation is started immediately and
    /// stopped with the service.
    func makeInstrumentation(runtime: ObservabilityRuntime) -> [Instrumentation]

    /// Built when the service starts, if automatic screen detection is enabled.
    func makeScreenViewCapture(runtime: ObservabilityRuntime) -> ScreenViewCapturing?

    /// Built when the service starts. Pending reports are flushed by the service.
    func makeCrashReporting(runtime: ObservabilityRuntime) -> CrashReporting?
}

extension ObservabilityInstrumenting {
    public func resolveAppLaunchSignal(appStartEndUptime: TimeInterval) -> AppLaunchSignal? { nil }
    public func makeUserInteractionManager(runtime: ObservabilityRuntime) -> UserInteractionManaging? { nil }
    public func makeInstrumentation(runtime: ObservabilityRuntime) -> [Instrumentation] { [] }
    public func makeScreenViewCapture(runtime: ObservabilityRuntime) -> ScreenViewCapturing? { nil }
    public func makeCrashReporting(runtime: ObservabilityRuntime) -> CrashReporting? { nil }
}
