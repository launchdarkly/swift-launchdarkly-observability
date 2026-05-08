import SwiftUI
import UIKit

struct SessionReplayModifier: ViewModifier {
    let isEnabled: Bool?
    let isIgnored: Bool?
    
    public func body(content: Content) -> some View {
        content.overlay(
            SessionReplayViewRepresentable(isEnabled: isEnabled, isIgnored: isIgnored)
                .allowsHitTesting(false)
        )
    }
}

struct SessionReplayViewRepresentable: UIViewRepresentable {
    public typealias Context = UIViewRepresentableContext<Self>

    let isEnabled: Bool?
    let isIgnored: Bool?

    public init(isEnabled: Bool?, isIgnored: Bool?) {
        self.isEnabled = isEnabled
        self.isIgnored = isIgnored
    }

    /// Marker view inserted by `.ldMask()` / `.ldUnmask()` / `.ldIgnore()` /
    /// `.ldPrivate(...)` SwiftUI modifiers.
    ///
    /// Because `SessionReplayModifier` attaches itself via `.overlay()`, this
    /// view ends up as a *sibling* of the modified content in the UIKit
    /// hierarchy — not an ancestor. The view itself carries the explicit
    /// mask/ignore state via associated objects; `MaskCollector` then detects
    /// these markers at collection time, walks up to the lowest common
    /// ancestor of the overlay branch and the content branch, and propagates
    /// the explicit state to that ancestor so it reaches the modified
    /// content.
    class MaskView: UIView {
        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            // We want to make sure the wrapper view created by SwiftUI also doesn't intercept touches
            superview?.isUserInteractionEnabled = false
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            superview?.isUserInteractionEnabled = false
        }

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            return false
        }
    }

    public func makeUIView(context: Context) -> MaskView {
        let view = MaskView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    public func updateUIView(_ uiView: MaskView, context: Context) {
        if let isEnabled {
            SessionReplayAssociatedObjects.maskUIView(uiView, isEnabled: isEnabled)
        }
        if let isIgnored {
            SessionReplayAssociatedObjects.ignoreUIView(uiView, isEnabled: isIgnored)
        }
    }
}
