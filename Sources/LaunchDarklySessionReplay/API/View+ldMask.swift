import SwiftUI
import UIKit

public extension View {
    func ldMask() -> some View {
        modifier(SessionReplayModifier(isEnabled: true, isIgnored: nil))
    }
    
    func ldPrivate(isEnabled: Bool = true) -> some View {
        modifier(SessionReplayModifier(isEnabled: isEnabled, isIgnored: nil))
    }
    
    func ldIgnore() -> some View {
        modifier(SessionReplayModifier(isEnabled: nil, isIgnored: true))
    }
    
    func ldUnmask() -> some View {
        modifier(SessionReplayModifier(isEnabled: false, isIgnored: nil))
    }
}

public extension UIView {
    func ldPrivate(isEnabled: Bool = true) {
        SessionReplayAssociatedObjects.maskUIView(self, isEnabled: isEnabled)
    }
    
    func ldUnmask() {
        SessionReplayAssociatedObjects.maskUIView(self, isEnabled: false)
    }
    
    func ldIgnore() {
        SessionReplayAssociatedObjects.ignoreUIView(self)
    }
}
