import Foundation
#if canImport(WebKit)
import WebKit
#endif
import UIKit
import SwiftUI
import Common

typealias PrivacySettings = SessionReplayOptions.PrivacyOptions


final class MaskCollector {
    enum Constants {
        static let maskiOS26ViewTypes = Set(["CameraUI.ChromeSwiftUIView"])
    }

    struct Settings {
        var maskiOS26ViewTypes: Set<String>
        var maskTextInputs: Bool
        var maskWebViews: Bool
        var maskImages: Bool
        var minimumAlpha: CGFloat
        var maskClasses: Set<ObjectIdentifier>
        var maskAccessibilityIdentifiers: Set<String>
        var ignoreAccessibilityIdentifiers: Set<String>
        
        init(privacySettings: PrivacySettings) {
            self.maskiOS26ViewTypes = Constants.maskiOS26ViewTypes
            self.maskTextInputs = privacySettings.maskTextInputs
            self.maskWebViews = privacySettings.maskWebViews
            self.maskImages = privacySettings.maskImages
            self.minimumAlpha = privacySettings.minimumAlpha
            self.maskClasses = privacySettings.buildMaskClasses()
            self.maskAccessibilityIdentifiers = Set(privacySettings.maskAccessibilityIdentifiers)
            self.ignoreAccessibilityIdentifiers = Set(privacySettings.ignoreAccessibilityIdentifiers)
        }
              
        func shouldMask(_ view: UIView) -> Bool {
            if let shouldUnmask = SessionReplayAssociatedObjects.shouldMaskUIView(view),
                !shouldUnmask {
                return false
            }
            
            if let accessibilityIdentifier = view.accessibilityIdentifier,
              ignoreAccessibilityIdentifiers.contains(accessibilityIdentifier) {
                return false
            }
            
            let viewType = type(of: view)
            let stringViewType = String(describing: viewType)
            
            if maskiOS26ViewTypes.contains(stringViewType) {
                return true
            }
            
            if maskWebViews {
#if canImport(WebKit)
                if let wkWebView = view as? WKWebView {
                    return true
                }
                if let uiWebView = view as? UIWebView {
                    return true
                }
#endif
            }
            
            if maskTextInputs  {
                if let textInput = view as? UITextInput {
#if canImport(WebKit)
                    if stringViewType != "WKContentView" {
                        return true
                    }
#else
                    return true
#endif
                }
                if stringViewType == "UIKeyboard" {
                    return true
                }
            }
            
            if maskImages, let imageView = view as? UIImageView {
                return true
            }
            
            if SessionReplayAssociatedObjects.shouldMaskSwiftUI(view) ?? false {
                return true
            }
            
            if SessionReplayAssociatedObjects.shouldMaskUIView(view) ?? false {
                return true
            }
            
            if let accessibilityIdentifier = view.accessibilityIdentifier,
               maskAccessibilityIdentifiers.contains(accessibilityIdentifier) {
                return true
            }
            
            return false
        }
    }

    var settings: Settings
    
    public init(privacySettings: PrivacySettings) {
        self.settings = Settings(privacySettings: privacySettings)
    }
    
    func collectViewMasks(in rootView: UIView, window: UIWindow, scale: CGFloat) -> [MaskOperation] {
        var result = [MaskOperation]()
        let root = rootView.layer
        let rPresenation = root.presentation() ?? root
        
        func visit(layer: CALayer) {
            guard let view = layer.delegate as? UIView,
                  !view.isHidden,
                  view.window != nil,
                  view.alpha >= settings.minimumAlpha
            else { return }
            
            //let layer = currentView.layer.presentation() ?? currentView.layer
            let effectiveFrame = rPresenation.convert(layer.frame, from: layer.superlayer)
            let shouldMask = settings.shouldMask(view)
            if shouldMask, let mask = createMask(rPresenation, root: root, layer: layer, scale: scale) {
                var operation = MaskOperation(mask: mask, kind: .fill, effectiveFrame: effectiveFrame)
                #if DEBUG
                operation.accessibilityIdentifier = view.accessibilityIdentifier
                #endif
                result.append(operation)
                return
            }
            
            if !isSystem(view: view, pLayer: layer) && !isTransparent(view: view, pLayer: layer), result.isNotEmpty {
              //  if view.accessibilityIdentifier != nil {
                    result.removeAll {
                        effectiveFrame.contains($0.effectiveFrame)
                    }
              //  }
            }
        
            if let sublayers = layer.sublayers?.sorted(by: { $0.zPosition < $1.zPosition }) {
                sublayers.forEach(visit)
            }
        }
        
        rPresenation.sublayers?.sorted { $0.zPosition < $1.zPosition }.forEach(visit)
        
        return result
    }
    
    func isTransparent(view: UIView, pLayer: CALayer) -> Bool {
        pLayer.opacity < 1 || view.alpha < 1.0 || view.backgroundColor == nil || (view.backgroundColor?.cgColor.alpha ?? 0) < 1.0
    }
    
    func isSystem(view: UIView, pLayer: CALayer) -> Bool {
       return false
    }
    
    func createMask(_ rPresenation: CALayer, root: CALayer, layer: CALayer, scale: CGFloat) -> Mask? {
        let scale = 1.0 // scale is already in layers
       // let rBounds = rPresenation.bounds
        let lBounds = layer.bounds
        guard lBounds.width > 0, lBounds.height > 0 else { return nil }

        //let lPresenation = layer.presentation() ?? layer
        if CATransform3DIsAffine(layer.transform) {
            let corner0 = layer.convert(CGPoint.zero, to: root)
            let corner1 = layer.convert(CGPoint(x: lBounds.width, y: 0), to: root)
            let corner3 = layer.convert(CGPoint(x: 0, y: lBounds.height), to: root)
            
            let tx = corner0.x, ty = corner0.y
            let affineTransform = CGAffineTransform(a: (corner1.x - tx) / max(lBounds.width, 0.0001),
                                                    b: (corner1.y - ty) / max(lBounds.width, 0.0001),
                                                    c: (corner3.x - tx) / max(lBounds.height, 0.0001),
                                                    d: (corner3.y - ty) / max(lBounds.height, 0.0001),
                                                    tx: tx,
                                                    ty: ty).scaledBy(x: scale, y: scale)
            return Mask.affine(rect: lBounds, transform: affineTransform)
        } else { // 3D animations
//            let corner0 = CGPoint.zero
//            let corner1 = CGPoint(x: lBounds.width, y: 0)
            
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
        let ids = Set(maskUIViews.map(ObjectIdentifier.init))
        
        
//            if privacySettings.maskTextInputs {
//                [UITextField.self, UITextView.self, UIWebView.self, UISearchTextField.self,
//                 SwiftUI.UITextView.self, SwiftUI.UITextView.self].forEach {
//                    ids.insert(ObjectIdentifier($0))
//                }
//            }
        return ids
    }
}
