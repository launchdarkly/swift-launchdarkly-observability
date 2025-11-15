import SwiftUI
import UIKit

struct SessionReplayModifier: ViewModifier {
    let isEnabled: Bool?
    let isIgnored: Bool?
    
    public func body(content: Content) -> some View {
        content.overlay(
            SessionReplayViewRepresentable(isEnabled: isEnabled, isIgnored: isIgnored)
            .disabled(true)
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
    
    class MaskView: UIView { }
    
    public func makeUIView(context: Context) -> MaskView {
        MaskView()
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
