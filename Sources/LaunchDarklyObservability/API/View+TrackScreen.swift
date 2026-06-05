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
#endif
