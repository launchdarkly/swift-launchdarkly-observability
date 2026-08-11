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
}
