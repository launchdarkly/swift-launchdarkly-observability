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
        /// Tap location in SwiftUI `.global` coordinates, when available. `.global` is the root of the
        /// SwiftUI hierarchy: it equals UIKit window coordinates for a full-screen window but is
        /// screen-relative when the window isn't (iPad Split View / Slide Over / Stage Manager). The
        /// lookup therefore matches against both the window point and the screen-converted point.
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
    /// How long a *locationless* entry (older SwiftUI versions that report no tap coordinates)
    /// stays eligible. Such entries can't be matched geometrically, so they would otherwise match
    /// any touch point for the whole `ttl` and let a later tap elsewhere inherit a previous
    /// button's id. Bounding them to a tight window keeps the match to the current event cycle
    /// (all pipelines resolve a tap back-to-back, well within this) without bleeding into the
    /// user's next, unrelated tap.
    private let locationlessFreshness: TimeInterval = 0.1

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

    /// Returns the id of the most recent located entry whose recorded location is within tolerance
    /// of any of [points], or nil. Passing several candidate points lets the caller reconcile
    /// coordinate spaces: a `.ldClick` location is recorded in SwiftUI `.global`, which the resolver
    /// can't disambiguate from UIKit window vs screen coordinates ahead of time (they diverge when
    /// the window isn't full-screen), so it supplies both. Only entries that carry a location are
    /// considered; locationless entries are resolved separately via ``locationlessId()`` so they can
    /// never match an arbitrary point. Non-consuming: entries are left in place (and expire by TTL)
    /// so multiple capture pipelines resolving the same tap all see the id.
    func id(atAnyOf points: [CGPoint]) -> String? {
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        defer { lock.unlock() }
        prune(now: now)
        for entry in entries.reversed() {
            guard let location = entry.location else { continue }
            for point in points {
                if abs(location.x - point.x) <= locationTolerance,
                   abs(location.y - point.y) <= locationTolerance {
                    return entry.id
                }
            }
        }
        return nil
    }

    /// Convenience for a single candidate point. See ``id(atAnyOf:)``.
    func id(at point: CGPoint) -> String? {
        id(atAnyOf: [point])
    }

    /// Returns the id of the most recent *locationless* entry, but only when it is fresh enough to
    /// belong to the current event cycle (see ``locationlessFreshness``). Older SwiftUI versions
    /// report taps without coordinates, so these can't be matched geometrically; the freshness
    /// bound keeps a later tap elsewhere from inheriting a previous button's id. Callers should
    /// treat this as a last resort, below both a located match and a UIKit `UIView.ldId`.
    /// Non-consuming.
    func locationlessId() -> String? {
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        defer { lock.unlock() }
        prune(now: now)
        for entry in entries.reversed() {
            guard entry.location == nil else { continue }
            if now - entry.time <= locationlessFreshness {
                return entry.id
            }
        }
        return nil
    }

    private func prune(now: TimeInterval) {
        entries.removeAll { now - $0.time > ttl }
    }
}
#endif
