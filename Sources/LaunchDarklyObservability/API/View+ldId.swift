#if canImport(UIKit)
import UIKit

public extension UIView {
    /// Tags this view with a stable analytics identifier used as `event.id` for auto-captured
    /// `click` events on this view (or its descendants, when the tap resolves to a child). Prefer a
    /// human-readable, stable id (e.g. `"checkout.pay_button"`). Takes precedence over
    /// `accessibilityIdentifier`.
    ///
    /// For SwiftUI, use the `.ldClick(_:)` view modifier instead.
    func ldId(_ id: String) {
        LdIdStorage.set(self, id: id)
    }
}
#endif
