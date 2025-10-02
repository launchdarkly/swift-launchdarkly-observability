import Foundation
import UIKit
import SwiftUI




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
            
//            if let imageView = view as? UIImageView {
//                return true
//            }
//            if let imageView = view as? UILabel {
//                return true
//            }
            
            return false
        }
    }

    var settings: Settings
    
    public init(privacySettings: PrivacySettings) {
        self.settings = Settings(privacySettings: privacySettings)
    }
    
    func collectViewMasks(in rootView: UIView, window: UIWindow) -> [Mask] {
        var result = [Mask]()
        let root = rootView.layer
        let rPresenation = root.presentation() ?? root
        guard var stack = rPresenation.sublayers else { return result }
        
        while let layer = stack.popLast() {
            guard let view = layer.delegate as? UIView,
                  !view.isHidden,
                  view.window != nil,
                  view.alpha >= settings.minimumAlpha
            else { continue }
            
            //let layer = currentView.layer.presentation() ?? currentView.layer
            let shouldMask = settings.shouldMask(view)
            if shouldMask, let mask = createMask(rPresenation, root: root, layer: layer) {
                result.append(mask)
                continue
            }
            
            if let sublayers = layer.sublayers {
                stack.append(contentsOf: sublayers)
            }
        }
        
        return result
    }
    
    func createMask(_ rPresenation: CALayer, root: CALayer, layer: CALayer) -> Mask? {
        let rBounds = rPresenation.bounds
        let lBounds = layer.bounds
        guard rBounds.width > 0, rBounds.height > 0 else { return nil }
        
        if CATransform3DIsAffine(rPresenation.transform) {
            let lPresenation = layer.presentation() ?? layer
            let corner0 = lPresenation.convert(CGPoint.zero, to: root)
            let corner1 = lPresenation.convert(CGPoint(x: lBounds.width, y: 0), to: root)
            let corner3 = lPresenation.convert(CGPoint(x: 0, y: lBounds.height), to: root)
            
            let tx = corner0.x, ty = corner0.y
            let affineTransform = CGAffineTransform(a: (corner1.x - tx) / max(rBounds.width, 0.0001),
                                                    b: (corner1.y - ty) / max(rBounds.width, 0.0001),
                                                    c: (corner3.x - tx) / max(rBounds.height, 0.0001),
                                                    d: (corner3.y - ty) / max(rBounds.height, 0.0001),
                                                    tx: tx,
                                                    ty: ty)
            return Mask.affine(rect: rBounds, transform: affineTransform)
        } else {
            let corner0 = CGPoint.zero
            let corner1 = CGPoint(x: lBounds.width, y: 0)
            
        }
        
        return nil
    }
    
    func rectFromPresentation(_ rPresenation: CALayer, root: CALayer, layer: CALayer) -> CGRect {
        let lPresenation = layer.presentation() ?? layer
        let corner1 = lPresenation.convert(CGPoint(x: 0, y: 0), to: root)
        let corner2 = lPresenation.convert(CGPoint(x: lPresenation.bounds.width, y: lPresenation.bounds.height), to: root)
        return CGRect(x: min(corner1.x, corner2.x),
                      y: min(corner1.y, corner2.y),
                      width: abs(corner2.x - corner1.x),
                      height: abs(corner2.y - corner1.y))
      
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
