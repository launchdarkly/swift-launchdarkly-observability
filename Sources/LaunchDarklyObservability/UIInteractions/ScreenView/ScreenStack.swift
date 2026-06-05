import Foundation

/// The outcome of recording a screen appearance.
struct ScreenTransition: Equatable {
    /// The screen viewed immediately before this one, if any.
    let previous: String?
    /// `true` when the recorded screen was already on top (a re-appearance), so the navigation
    /// history is unchanged. Callers should skip emitting navigation/analytics events in this case
    /// to avoid duplicates.
    let isReappearance: Bool
}

/// Thread-safe holder of the navigation history of viewed screens.
///
/// It is the single source of truth used by both the automatic
/// (`ViewControllerScreenSource`) and manual (`LDObserve.trackScreenView`) paths
/// to resolve `event.previous_screen`.
///
/// `record(_:)` returns the previous screen name and whether the appearance was a re-appearance
/// of the current top, then updates the stack. Re-recording the screen that is already on top is
/// treated as a no-op (its `previous_screen` stays stable and the stack is left unchanged), so it
/// is robust to UIKit re-presenting the same controller (e.g. modal dismissals calling
/// `viewDidAppear` again).
final class ScreenStack {
    private let queue = DispatchQueue(label: "com.launchdarkly.observability.screenStack")
    private var stack: [String] = []

    init() {}

    /// Records a screen appearance and returns the resulting ``ScreenTransition``.
    @discardableResult
    func record(_ name: String) -> ScreenTransition {
        queue.sync {
            // Re-appearance of the current top: keep history stable.
            if stack.last == name {
                let previous = stack.count >= 2 ? stack[stack.count - 2] : nil
                return ScreenTransition(previous: previous, isReappearance: true)
            }

            let previous = stack.last

            // If the screen already exists deeper in the stack, treat the
            // appearance as a "pop back" to it and trim everything above.
            if let existingIndex = stack.lastIndex(of: name) {
                stack.removeSubrange((existingIndex + 1)..<stack.count)
            } else {
                stack.append(name)
            }

            return ScreenTransition(previous: previous, isReappearance: false)
        }
    }

    /// The most recently viewed screen, if any.
    var current: String? {
        queue.sync { stack.last }
    }

    /// Test/diagnostic snapshot of the current stack.
    var snapshot: [String] {
        queue.sync { stack }
    }

    func reset() {
        queue.sync { stack.removeAll() }
    }
}
