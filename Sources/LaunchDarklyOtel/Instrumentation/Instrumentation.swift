import Foundation

/// A unit of automatic instrumentation contributed by a package layered on top of the
/// core OTel pipeline. Started and stopped by the pipeline alongside the transport, so
/// instrumentation never has to reach into the pipeline's lifecycle itself.
public protocol Instrumentation: AnyObject {
    func start()
    func stop()
}

/// Automatic screen detection. Kept separate from plain ``Instrumentation`` because the
/// pipeline has to re-seed a newly started session with the screen the user is still
/// viewing: UIKit fires no appearance callback for an already-visible screen, so without
/// this the new session would open with no `screen_view`.
public protocol ScreenViewCapturing: Instrumentation {
    func captureCurrentScreen()
}

/// Delivery of pending crash reports collected by a previous process.
public protocol CrashReporting {
    func logPendingCrashReports()
}

/// The touch-capture pipeline. Declared here rather than in the instrumentation package
/// because ``ObservabilityContext`` carries it to Session Replay, which drives capture
/// independently of whether tap analytics are enabled.
///
/// Implementations must install their capture hook only on ``start()``, and ``start()``
/// must be idempotent: tap instrumentation and Session Replay may each call it.
public protocol UserInteractionManaging: AnyObject {
    func start()
    func stop()

    /// Whether an embedder resolves clicks for its own views, in which case tap detection must stop
    /// describing taps that land on an embedder surface.
    ///
    /// Flutter draws its entire UI into one `FlutterView`, so a native hit-test bottoms out there for
    /// every tap no matter which widget was pressed. Only Dart can see the widget tree, so the Flutter
    /// plugin resolves the target itself and reports it through `trackClick`. This flag is the
    /// embedder's half of that handshake: it is set only once Dart's click detection is actually
    /// installed, so an app that never installs it keeps the coarse native clicks rather than silently
    /// reporting none.
    ///
    /// Scoped to the touched view rather than switching off tap detection globally, because the
    /// embedder is not always the whole app: in an add-to-app host, native screens sit alongside a
    /// `FlutterViewController` and must keep reporting their real targets.
    var embedderHandlesClicks: Bool { get set }
}
