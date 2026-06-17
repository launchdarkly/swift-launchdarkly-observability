#if canImport(UIKit)
import SwiftUI

public extension View {
    /// Tags this SwiftUI element so an auto-captured `click` event reports `event.id == id` when the
    /// user taps it. Prefer a human-readable, stable id (e.g. `"checkout.pay_button"`).
    ///
    /// Unlike approaches that bridge the SwiftUI view tree into UIKit, this attaches a SwiftUI tap
    /// gesture that fires during the tap and records the id; the SDK's interaction capture then uses
    /// it. It relies only on public SwiftUI gesture APIs, so it is robust across SwiftUI/iOS versions,
    /// and it does not modify `accessibilityIdentifier` or the view hierarchy. The underlying control
    /// stays fully interactive (the gesture is attached simultaneously).
    func ldClick(_ id: String) -> some View {
        modifier(LdClickModifier(id: id))
    }
}

private struct LdClickModifier: ViewModifier {
    let id: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, tvOS 16.0, *) {
            // `.global` is the root of the SwiftUI hierarchy: it matches UIKit window coordinates
            // for a full-screen window but is screen-relative otherwise. The interaction resolver
            // reconciles both spaces when matching, so taps still resolve under iPad multitasking.
            content.simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .global).onEnded { value in
                    LdClickRegistry.shared.record(id: id, location: value.location)
                }
            )
        } else {
            content.simultaneousGesture(
                TapGesture().onEnded {
                    LdClickRegistry.shared.record(id: id, location: nil)
                }
            )
        }
    }
}
#endif
