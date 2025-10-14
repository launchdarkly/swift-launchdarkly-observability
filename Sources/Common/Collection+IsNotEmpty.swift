import Foundation

/// Convenience property for Collections to check non-emptiness.
/// Works for `Array`, `Set`, `Dictionary`, `String`, and any `Collection`.
public extension Collection {
    /// Returns `true` when the collection is not empty.
    var isNotEmpty: Bool { !isEmpty }
}

/// Convenience property to check if an optional Collection is nil or empty.
/// Works for `String`, `Array`, `Set`, `Dictionary`, and any `Collection` type.
public extension Optional where Wrapped: Collection {
    /// Returns `true` when the optional is `nil` or the wrapped collection is empty.
    var isNilOrEmpty: Bool { self?.isEmpty ?? true }
}
