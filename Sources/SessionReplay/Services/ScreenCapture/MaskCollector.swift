import Foundation
import UIKit
import SwiftUI


struct ViewMask {
    let rect: CGRect
}

typealias PrivacySettings = SessionReplayOptions.PrivacySettings

final class MaskCollector {
    struct Settings {
        var maskiOS26ViewTypes: Set<String>
        var maskTextInputs: Bool
        var minimumAlpha: CGFloat
        var maskClasses: Set<ObjectIdentifier>
        
        init(privacySettings: PrivacySettings) {
            self.maskiOS26ViewTypes = Set(privacySettings.maskiOS26TypeIds)
            self.maskTextInputs = privacySettings.maskTextInputs
            self.minimumAlpha = privacySettings.minimumAlpha
            self.maskClasses = privacySettings.buildMaskClasses()
        }
              
        func shouldMask(_ view: UIView) -> Bool {
            if maskiOS26ViewTypes.contains(String(describing: type(of: view))) {
                return true
            }
            
            if maskTextInputs, let textInput = view as? UITextInput {
                return true
            }
            
            return false
        }
    }

    var settings: Settings
    
    public init(privacySettings: PrivacySettings) {
        self.settings = Settings(privacySettings: privacySettings)
    }
    
    func collectViewMasks(in rootView: UIView, window: UIWindow) -> [ViewMask] {
        var result = [ViewMask]()
        var stack = [rootView]
        let rootLayer = rootView.layer
        
        while let currentView = stack.popLast() {
            guard !currentView.isHidden,
                    currentView.window != nil,
                  currentView.alpha >= settings.minimumAlpha else { return [] }
            
            let layer = currentView.layer.presentation() ?? currentView.layer
            
            guard !settings.shouldMask(currentView) else {
                let rect = currentView.convert(currentView.bounds, to: window)
                result.append(ViewMask(rect: rect))
                continue
            }
        
            
            let subviews = currentView.subviews
            stack.append(contentsOf: subviews)
        }
        
        return result
    }
}

extension PrivacySettings {
    func buildMaskClasses() -> Set<ObjectIdentifier> {
        var ids = Set(maskClasses.map(ObjectIdentifier.init))
//            if privacySettings.maskTextInputs {
//                [UITextField.self, UITextView.self, UIWebView.self, UISearchTextField.self,
//                 SwiftUI.UITextView.self, SwiftUI.UITextView.self].forEach {
//                    ids.insert(ObjectIdentifier($0))
//                }
//            }
        return ids
    }
}
