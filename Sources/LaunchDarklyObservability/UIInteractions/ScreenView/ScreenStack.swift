import Foundation

/// Thread-safe holder of the navigation history of viewed screens.
///
/// It is the single source of truth used by both the automatic
/// (`ViewControllerScreenSource`) and manual (`LDObserve.trackScreenView`) paths
/// to resolve `event.previous_screen`.
///
/// `record(_:id:)` returns the name of the screen that was viewed immediately before
/// the supplied one, then updates the stack. Re-recording the screen that is
/// already on top keeps history stable (its `previous_screen` stays the same and no
/// new entry is pushed), so it is robust to UIKit re-presenting the same controller
/// (e.g. modal dismissals calling `viewDidAppear` again). The matched entry's stored
/// `name`/`id` are still refreshed to the latest values, so `current`/`currentId`
/// never lag behind the most recent `screen_view` for the same identity.
///
/// Screen identity is keyed on `screenId` when supplied, falling back to `name`.
/// This keeps two distinct screens that share a display name (e.g. a detail screen
/// reused with per-item `screenId`s) from being collapsed into one another, while
/// `previous_screen` is still reported using the human-readable name.
final class ScreenStack {
    private struct Entry {
        /// Identity used for re-appearance and pop-back matching.
        let key: String
        /// Human-readable name reported as `previous_screen`.
        let name: String
        /// Caller-supplied stable screen id (`event.screen_id`), if any. `nil` when the
        /// screen was recorded without an explicit id (identity then falls back to `name`).
        let id: String?
    }

    private let queue = DispatchQueue(label: "com.launchdarkly.observability.screenStack")
    private var stack: [Entry] = []

    init() {}

    /// Records a screen appearance and returns the previous screen name (if any).
    @discardableResult
    func record(_ name: String, id: String? = nil) -> String? {
        let key = id ?? name
        return queue.sync {
            // Re-appearance of the current top: keep history stable, but refresh the
            // stored name/id so `current`/`currentId` track the latest screen view
            // (the same `screenId` can be re-recorded with an updated display name).
            if stack.last?.key == key {
                stack[stack.count - 1] = Entry(key: key, name: name, id: id)
                return stack.count >= 2 ? stack[stack.count - 2].name : nil
            }

            let previous = stack.last?.name

            // If the screen already exists deeper in the stack, treat the
            // appearance as a "pop back" to it and trim everything above. Refresh the
            // matched entry's name/id to the latest values so it doesn't go stale.
            if let existingIndex = stack.lastIndex(where: { $0.key == key }) {
                stack.removeSubrange((existingIndex + 1)..<stack.count)
                stack[existingIndex] = Entry(key: key, name: name, id: id)
            } else {
                stack.append(Entry(key: key, name: name, id: id))
            }

            return previous
        }
    }

    /// The most recently viewed screen name, if any.
    var current: String? {
        queue.sync { stack.last?.name }
    }

    /// The stable id (`event.screen_id`) of the most recently viewed screen, if it had one.
    /// Used to attach `event.screen_id` to `click` spans so taps correlate with the current
    /// `screen_view`. Returns `nil` when the current screen was recorded without an id.
    var currentId: String? {
        queue.sync { stack.last?.id }
    }

    /// Test/diagnostic snapshot of the current stack (screen names).
    var snapshot: [String] {
        queue.sync { stack.map { $0.name } }
    }

    func reset() {
        queue.sync { stack.removeAll() }
    }
}
