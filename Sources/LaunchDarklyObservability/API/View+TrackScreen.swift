#if canImport(SwiftUI)
import SwiftUI

public extension View {
    /// Records a `screen_view` event when this view appears.
    ///
    /// Use this on SwiftUI screens that automatic `UIViewController` capture
    /// cannot observe (e.g. `NavigationStack` destinations). `previous_screen`
    /// is resolved through the same shared screen stack used by automatic
    /// capture, so a single call per screen appearance is enough.
    ///
    /// - Parameters:
    ///   - name: The human-readable screen name (`event.name`, required).
    ///   - screenClass: The screen's class/type (`event.screen_class`).
    ///   - screenId: A stable screen identifier (`event.screen_id`).
    ///   - category: An optional screen group (`event.category`).
    func trackScreen(
        _ name: String,
        screenClass: String? = nil,
        screenId: String? = nil,
        category: String? = nil
    ) -> some View {
        modifier(
            TrackScreenModifier(
                name: name,
                screenClass: screenClass,
                screenId: screenId,
                category: category
            )
        )
    }
}

private struct TrackScreenModifier: ViewModifier {
    let name: String
    let screenClass: String?
    let screenId: String?
    let category: String?

    func body(content: Content) -> some View {
        content.onAppear {
            LDObserve.shared.trackScreenView(
                name: name,
                screenClass: screenClass,
                screenId: screenId,
                category: category
            )
        }
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public extension View {
    /// Records `screen_view` events driven by a `NavigationStack` path, covering both pushes and
    /// pops (including returning to the root).
    ///
    /// SwiftUI does not reliably re-run `.onAppear` when you pop back to a screen, so appearance-
    /// based tracking (``trackScreen(_:screenClass:screenId:category:)``) misses back-navigation.
    /// Apply this to the `NavigationStack` instead: the top of `path` (or the root when `path` is
    /// empty) is recorded on first appearance and on every path change.
    ///
    /// - Parameters:
    ///   - path: The same value bound to `NavigationStack(path:)`.
    ///   - root: The screen name to record when `path` is empty (the stack's root).
    ///   - destination: Maps a path element to its screen name. Return `nil` to skip a destination
    ///     that records itself (e.g. a child that already calls `trackScreen`).
    func trackScreenStack<Element: Hashable>(
        _ path: [Element],
        root: String,
        destination: @escaping (Element) -> String?
    ) -> some View {
        modifier(TrackScreenStackModifier(path: path, root: root, destination: destination))
    }

    /// Records a `screen_view` for this screen when a presentation (`sheet`, `fullScreenCover`,
    /// etc.) bound to `isPresented` is dismissed.
    ///
    /// SwiftUI does not re-run the presenter's `.onAppear` when a sheet closes, so the underlying
    /// screen would otherwise be missing from the timeline after returning from a modal. Apply this
    /// to the presenting screen, passing the same flag (or a combination of flags) used to drive
    /// its presentations.
    ///
    /// - Parameters:
    ///   - name: The screen name to record on return (`event.name`).
    ///   - screenClass: The screen's class/type (`event.screen_class`).
    ///   - screenId: A stable screen identifier (`event.screen_id`).
    ///   - category: An optional screen group (`event.category`).
    ///   - isPresented: `true` while a modal is presented; a `true` -> `false` transition records
    ///     the screen. Combine multiple flags (e.g. `a || b || c`) to fire once any modal closes.
    func trackScreenReturn(
        _ name: String,
        screenClass: String? = nil,
        screenId: String? = nil,
        category: String? = nil,
        isPresented: Bool
    ) -> some View {
        modifier(
            TrackScreenReturnModifier(
                name: name,
                screenClass: screenClass,
                screenId: screenId,
                category: category,
                isPresented: isPresented
            )
        )
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
private struct TrackScreenStackModifier<Element: Hashable>: ViewModifier {
    let path: [Element]
    let root: String
    let destination: (Element) -> String?

    func body(content: Content) -> some View {
        content
            .onAppear { emit(for: path) }
            .onChange(of: path) { newPath in emit(for: newPath) }
    }

    private func emit(for path: [Element]) {
        // The top of the stack is the current screen; an empty path means the root.
        let name: String?
        if let top = path.last {
            name = destination(top)
        } else {
            name = root
        }
        guard let name else { return }
        LDObserve.shared.trackScreenView(name: name)
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
private struct TrackScreenReturnModifier: ViewModifier {
    let name: String
    let screenClass: String?
    let screenId: String?
    let category: String?
    let isPresented: Bool

    func body(content: Content) -> some View {
        // `onChange` only fires on a transition, so a `false` value here means a modal just closed.
        content.onChange(of: isPresented) { presented in
            guard !presented else { return }
            LDObserve.shared.trackScreenView(
                name: name,
                screenClass: screenClass,
                screenId: screenId,
                category: category
            )
        }
    }
}
#endif
