import SwiftUI
import UIKit
import SessionReplay

public extension View {
    func ldMask(isEnabled: Bool = true) -> some View {
        modifier(SessionReplayModifier(isEnabled: isEnabled))
    }
    
    func ldUnmask() -> some View {
        modifier(SessionReplayModifier(isEnabled: false))
    }
}

public extension UIView {
    func ldMask(isEnabled: Bool = true) {
        SessionReplayAssociatedObjects.maskUIView(self, isEnabled: isEnabled)
    }
    
    func ldUnmask() {
        SessionReplayAssociatedObjects.maskUIView(self, isEnabled: false)
    }
}
