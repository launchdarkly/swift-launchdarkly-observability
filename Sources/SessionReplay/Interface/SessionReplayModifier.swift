import SwiftUI
import UIKit
import SessionReplay

struct SessionReplayModifier: ViewModifier {
    let isEnabled: Bool
    
    public func body(content: Content) -> some View {
        content.overlay(SessionReplayViewRepresentable(isEnabled: isEnabled)).disabled(true)
    }
}

struct SessionReplayViewRepresentable: UIViewRepresentable {
    public typealias Context = UIViewRepresentableContext<Self>

    let isEnabled: Bool

    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
    
    class MaskView: UIView { }
    
    public func makeUIView(context: Context) -> MaskView {
        MaskView()
    }
    
    public func updateUIView(_ uiView: MaskView, context: Context) {
        SessionReplayAssociatedObjects.maskSwiftUI(uiView, isEnabled: isEnabled)
    }
}
