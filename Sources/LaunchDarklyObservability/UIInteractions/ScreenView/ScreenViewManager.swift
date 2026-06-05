import Foundation

/// Drives automatic `screen_view` capture by starting the `UIViewController`
/// swizzle source and forwarding each appearing screen to the supplied callback.
///
/// Mirrors `UserInteractionManager`: construction wires the source, and `start()`
/// activates the swizzle. The callback is invoked on the main thread (UIKit's
/// `viewDidAppear` runs on the main thread).
final class ScreenViewManager {
    private let onScreenView: (ScreenView) -> Void
    #if canImport(UIKit)
    private let source = ViewControllerScreenSource()
    #endif

    init(onScreenView: @escaping (ScreenView) -> Void) {
        self.onScreenView = onScreenView
    }

    func start() {
        #if canImport(UIKit)
        source.start { [onScreenView] screen in
            onScreenView(screen)
        }
        #endif
    }

    /// Re-emits the screen the user is currently viewing, as if it had just appeared. Used to seed
    /// a fresh session (after a session-id change) so the new session gets an opening `screen_view`
    /// span and `Navigate` event even though no `viewDidAppear` fires for the on-screen controller.
    func captureCurrentScreen() {
        #if canImport(UIKit)
        source.captureCurrent()
        #endif
    }

    func stop() {
        #if canImport(UIKit)
        source.stop()
        #endif
    }
}
