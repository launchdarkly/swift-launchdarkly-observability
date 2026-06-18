import UIKit

public protocol UIEventSource: AnyObject {
    /// Installs the event hook. For every `UIWindow.sendEvent`, the source invokes `handler`
    /// with the event, its window, and a `dispatchOriginal` thunk that forwards the event to the
    /// app's original `sendEvent` implementation.
    ///
    /// The handler controls when the app sees the event by calling `dispatchOriginal()`. This lets
    /// a consumer sample state that the app mutates synchronously during dispatch (e.g. the active
    /// screen, which a navigating tap handler changes) *before* calling `dispatchOriginal()`, while
    /// still resolving anything that the app populates *during* dispatch (e.g. SwiftUI `.ldClick`
    /// gesture ids) *after* it. The handler must call `dispatchOriginal()` exactly once, otherwise
    /// the app stops receiving events.
    func start(handler: @escaping (UIEvent, UIWindow, _ dispatchOriginal: () -> Void) -> Void)
    func stop()
}

public protocol UIEventBus: Sendable {
    func publish(_ event: TouchInteraction)
}
