import Foundation

/// Thread-safe holder of the navigation history of viewed screens.
///
/// It is the single source of truth used by both the automatic
/// (`ViewControllerScreenSource`) and manual (`LDObserve.trackScreenView`) paths
/// to resolve `event.previous_screen`.
///
/// `record(_:id:)` returns the name of the screen that was viewed immediately before
/// the supplied one, then updates the stack. Re-recording the screen that is
/// already on top is treated as a no-op (its `previous_screen` stays stable and
/// the stack is left unchanged), so it is robust to UIKit re-presenting the same
/// controller (e.g. modal dismissals calling `viewDidAppear` again).
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
    }

    private let queue = DispatchQueue(label: "com.launchdarkly.observability.screenStack")
    private var stack: [Entry] = []

    init() {}

    /// Records a screen appearance and returns the previous screen name (if any).
    @discardableResult
    func record(_ name: String, id: String? = nil) -> String? {
        let key = id ?? name
        return queue.sync {
            // Re-appearance of the current top: keep history stable.
            if stack.last?.key == key {
                return stack.count >= 2 ? stack[stack.count - 2].name : nil
            }

            let previous = stack.last?.name

            // If the screen already exists deeper in the stack, treat the
            // appearance as a "pop back" to it and trim everything above.
            if let existingIndex = stack.lastIndex(where: { $0.key == key }) {
                stack.removeSubrange((existingIndex + 1)..<stack.count)
            } else {
                stack.append(Entry(key: key, name: name))
            }

            return previous
        }
    }

    /// The most recently viewed screen name, if any.
    var current: String? {
        queue.sync { stack.last?.name }
    }

    /// Test/diagnostic snapshot of the current stack (screen names).
    var snapshot: [String] {
        queue.sync { stack.map { $0.name } }
    }

    func reset() {
        queue.sync { stack.removeAll() }
    }
}
