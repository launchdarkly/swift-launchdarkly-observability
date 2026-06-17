#if canImport(UIKit)
import UIKit

/// Bridges SwiftUI `.ldClick(_:)` taps to the auto-capture pipeline.
///
/// `.ldClick(_:)` attaches a SwiftUI tap gesture that fires *during* the tap and records the id
/// here. The SDK swizzles `UIWindow.sendEvent` and calls the original implementation first (which is
/// what fires SwiftUI's gesture callbacks), then resolves the touch target in the same event cycle —
/// so a freshly recorded id is available when `TargetResolver` runs and is used as `event.id`.
///
/// This is best-effort: it never emits its own span, so it can never create duplicate `click`
/// events. If no fresh id matches (e.g. an unusual SwiftUI version defers the gesture callback), the
/// click span is simply emitted without an id, exactly as it would be today.
///
/// Lookups are non-consuming: a single tap is read by multiple independent capture pipelines
/// (Observability emits the `click` span; Session Replay emits its own click event), each with its
/// own `TargetResolver`. Entries expire by TTL instead of being removed on read so every pipeline
/// resolving the same tap sees the same id.
final class LdClickRegistry {
    static let shared = LdClickRegistry()

    private struct Entry {
        let id: String
        /// Tap location in `.global` SwiftUI coordinates (≈ window coordinates), when available.
        let location: CGPoint?
        let time: TimeInterval
    }

    private let lock = NSLock()
    private var entries: [Entry] = []

    /// How long a recorded tap remains eligible. Resolution happens within the same `sendEvent`
    /// cycle, so this only needs to cover that brief window plus scheduling jitter.
    private let ttl: TimeInterval = 0.75
    /// Allowed distance between the gesture location and the resolved touch point.
    private let locationTolerance: CGFloat = 24

    init() {}

    /// Records a `.ldClick(_:)` activation. Called on the main thread from the SwiftUI gesture.
    func record(id: String, location: CGPoint?) {
        guard !id.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        prune(now: now)
        entries.append(Entry(id: id, location: location, time: now))
        lock.unlock()
    }

    /// Returns the best-matching id for a touch at [point] (window coordinates), or nil. Prefers the
    /// most recent entry whose recorded location is within tolerance; entries without a location
    /// (older SwiftUI versions) match on recency alone. Non-consuming: entries are left in place (and
    /// expire by TTL) so multiple capture pipelines resolving the same tap all see the id.
    func id(at point: CGPoint) -> String? {
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        defer { lock.unlock() }
        prune(now: now)
        for entry in entries.reversed() {
            if let location = entry.location {
                guard abs(location.x - point.x) <= locationTolerance,
                      abs(location.y - point.y) <= locationTolerance else {
                    continue
                }
            }
            return entry.id
        }
        return nil
    }

    private func prune(now: TimeInterval) {
        entries.removeAll { now - $0.time > ttl }
    }
}
#endif
