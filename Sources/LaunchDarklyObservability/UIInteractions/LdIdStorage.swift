#if canImport(UIKit)
import UIKit

/// Stores a developer-supplied analytics identifier (`ldId`) on a `UIView` via an associated
/// object. This is a dedicated channel, separate from `accessibilityIdentifier`, so the two can
/// differ and `ldId` can take precedence when resolving `event.id` for `click` events.
enum LdIdStorage {
    private static var key: UInt8 = 0

    static func set(_ view: UIView, id: String) {
        objc_setAssociatedObject(view, &key, id, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func get(_ view: UIView) -> String? {
        objc_getAssociatedObject(view, &key) as? String
    }
}
#endif
