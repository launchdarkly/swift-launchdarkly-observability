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
        let rootLayer = rootView.layer.presentation() ?? rootView.layer
        guard var stack = rootLayer.sublayers else { return result }
        
        while let layer = stack.popLast() {
            guard let currentView = layer.delegate as? UIView,
                    !currentView.isHidden,
                    currentView.window != nil,
                  currentView.alpha >= settings.minimumAlpha
            else { continue }
            
            //let layer = currentView.layer.presentation() ?? currentView.layer
            
            if settings.shouldMask(currentView) {
                let rect = currentView.convert(layer.bounds, to: window)
                result.append(ViewMask(rect: rect))
                continue
            }
        
            if let sublayers = layer.sublayers {
                stack.append(contentsOf: sublayers)
            }
        }
        
        return result
    }
}

extension PrivacySettings {
    func buildMaskClasses() -> Set<ObjectIdentifier> {
        var ids = Set(maskUIViews.map(ObjectIdentifier.init))
//            if privacySettings.maskTextInputs {
//                [UITextField.self, UITextView.self, UIWebView.self, UISearchTextField.self,
//                 SwiftUI.UITextView.self, SwiftUI.UITextView.self].forEach {
//                    ids.insert(ObjectIdentifier($0))
//                }
//            }
        return ids
    }
}
