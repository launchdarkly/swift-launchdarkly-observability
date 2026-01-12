import SwiftUI
import UIKit

struct SessionReplayModifier: ViewModifier {
    let isEnabled: Bool?
    let isIgnored: Bool?
    
    public func body(content: Content) -> some View {
        content.background(
            SessionReplayViewRepresentable(isEnabled: isEnabled, isIgnored: isIgnored)
            .disabled(true)
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
    
    class MaskView: UIView {
        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            
            if let wrapper = superview {
                wrapper.isUserInteractionEnabled = false
            }
        }
        
        override func didMoveToWindow() {
            super.didMoveToWindow()
            
            if let wrapper = superview {
                wrapper.isUserInteractionEnabled = false
            }
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
