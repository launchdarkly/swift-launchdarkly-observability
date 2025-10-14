import SwiftUI
import UIKit

public extension View {
    func ldPrivate(isEnabled: Bool = true) -> some View {
        modifier(SessionReplayModifier(isEnabled: isEnabled))
    }
    
    func ldUnmask() -> some View {
        modifier(SessionReplayModifier(isEnabled: false))
    }
}

public extension UIView {
    func ldPrivate(isEnabled: Bool = true) {
        SessionReplayAssociatedObjects.maskUIView(self, isEnabled: isEnabled)
    }
    
    func ldUnmask() {
        SessionReplayAssociatedObjects.maskUIView(self, isEnabled: false)
    }
}
