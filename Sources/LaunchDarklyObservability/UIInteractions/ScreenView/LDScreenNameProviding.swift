#if canImport(UIKit)
import UIKit

/// Adopt on a `UIViewController` to customize how it is reported as a `screen_view`.
///
/// When automatic screen tracking captures a controller, these values take
/// precedence over the derived defaults (title / cleaned class name).
public protocol LDScreenNameProviding {
    /// Human-readable screen name (maps to `event.name`). Return `nil` to fall back to defaults.
    var ldScreenName: String? { get }
    /// Optional screen group (maps to `event.category`).
    var ldScreenCategory: String? { get }
}

public extension LDScreenNameProviding {
    var ldScreenCategory: String? { nil }
}
#endif
