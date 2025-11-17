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
        
        var maskUIViews: Set<ObjectIdentifier>
        var unmaskUIViews: Set<ObjectIdentifier>
        var ignoreUIViews: Set<ObjectIdentifier>
        
        var maskAccessibilityIdentifiers: Set<String>
        var unmaskAccessibilityIdentifiers: Set<String>
        var ignoreAccessibilityIdentifiers: Set<String>
        
        init(privacySettings: PrivacySettings) {
            self.maskiOS26ViewTypes = Constants.maskiOS26ViewTypes
            self.maskTextInputs = privacySettings.maskTextInputs
            self.maskWebViews = privacySettings.maskWebViews
            self.maskImages = privacySettings.maskImages
            self.minimumAlpha = privacySettings.minimumAlpha
            
            self.maskUIViews = Set(privacySettings.maskUIViews.map(ObjectIdentifier.init))
            self.unmaskUIViews = Set(privacySettings.unmaskUIViews.map(ObjectIdentifier.init))
            self.ignoreUIViews = Set(privacySettings.ignoreUIViews.map(ObjectIdentifier.init))
            
            self.maskAccessibilityIdentifiers = Set(privacySettings.maskAccessibilityIdentifiers)
            self.unmaskAccessibilityIdentifiers = Set(privacySettings.unmaskAccessibilityIdentifiers)
            self.ignoreAccessibilityIdentifiers = Set(privacySettings.ignoreAccessibilityIdentifiers)
        }
        
        func shouldIgnore(_ view: UIView) -> Bool {
            let viewType = type(of: view)
            if SessionReplayAssociatedObjects.shouldIgnoreUIView(view) == true {
                return true
            }
            
            if ignoreUIViews.contains(ObjectIdentifier(viewType)) {
                return true
            }
            
            if let accessibilityIdentifier = view.accessibilityIdentifier,
               ignoreAccessibilityIdentifiers.contains(accessibilityIdentifier) {
                return true
            }
            
            return false
        }
        
        func shouldMask(_ view: UIView) -> Bool {
            if let shouldUnmask = SessionReplayAssociatedObjects.shouldMaskUIView(view),
               !shouldUnmask {
                return false
            }
            
            if let accessibilityIdentifier = view.accessibilityIdentifier,
               unmaskAccessibilityIdentifiers.contains(accessibilityIdentifier) {
                return false
            }
                        
            let viewType = type(of: view)
            let viewIdentifier = ObjectIdentifier(viewType)
            if unmaskUIViews.contains(viewIdentifier) {
                return false
            }
            
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
            
            if maskUIViews.contains(viewIdentifier) {
                return true
            }
            
            if let accessibilityIdentifier = view.accessibilityIdentifier,
               maskAccessibilityIdentifiers.contains(accessibilityIdentifier) {
                return true
            }

            return SessionReplayAssociatedObjects.shouldMaskUIView(view) == true
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
            
            guard !settings.shouldIgnore(view) else { return }
            
            let effectiveFrame = rPresenation.convert(layer.frame, from: layer.superlayer)

            let shouldMask = settings.shouldMask(view)
            if shouldMask, let mask = createMask(rPresenation, layer: layer, scale: scale) {
                var operation = MaskOperation(mask: mask, kind: .fill, view: view, effectiveFrame: effectiveFrame)
#if DEBUG
                operation.accessibilityIdentifier = view.accessibilityIdentifier
#endif
                result.append(operation)
                return
            }
            
            if !isSystem(view: view, pLayer: layer) && !isTransparent(view: view, pLayer: layer), result.isNotEmpty {
                result.removeAll {
                    effectiveFrame.contains($0.effectiveFrame)
                }
            }
            
            if let sublayers = layer.sublayers?.sorted(by: { $0.zPosition < $1.zPosition }) {
                sublayers.forEach(visit)
            }
        }
        
        rPresenation.sublayers?.sorted { $0.zPosition < $1.zPosition }.forEach(visit)
        
        return result
    }
  
    func duplicateUnsimilar(in rootView: UIView, operations: [MaskOperation], scale: CGFloat) -> [MaskOperation]? {
        let rPresenation = rootView.layer.presentation() ?? rootView.layer
        let moveTollerance = 1.0
        var result = operations
        for operation in operations {
            let layer = operation.view.layer
            let prensationLayer = layer.presentation() ?? layer
            let effectiveFrame = rPresenation.convert(prensationLayer.frame, from: prensationLayer.superlayer)
            let diffX = abs(effectiveFrame.minX - operation.effectiveFrame.minX)
            let diffY = abs(effectiveFrame.minY - operation.effectiveFrame.minY)
            guard diffX > moveTollerance || diffX > moveTollerance else {
                // If movement is present we duplicate the frame
                continue
            }
            guard diffX < effectiveFrame.width, diffY < effectiveFrame.height else {
                // If movement is bigger the size we drop the frame
                return nil
            }
            
            guard let mask = createMask(rPresenation, layer: prensationLayer, scale: scale) else {
                continue
            }
            
            var newoperation = operation
            newoperation.kind = .fillDuplicate
            newoperation.mask = mask
            newoperation.effectiveFrame = effectiveFrame
            result.append(newoperation)
        }
        
        return result
    }
    
    private func isTransparent(view: UIView, pLayer: CALayer) -> Bool {
        pLayer.opacity < 1 || view.alpha < 1.0 || view.backgroundColor == nil || (view.backgroundColor?.cgColor.alpha ?? 0) < 1.0
    }
    
    private func isSystem(view: UIView, pLayer: CALayer) -> Bool {
        return false
    }
    
    func createMask(_ rPresenation: CALayer, layer: CALayer, scale: CGFloat) -> Mask? {
        let scale = 1.0
        let lBounds = layer.bounds
        guard lBounds.width > 0, lBounds.height > 0 else { return nil }
        
        if CATransform3DIsAffine(layer.transform) {
            let corner0 = layer.convert(CGPoint.zero, to: rPresenation)
            let corner1 = layer.convert(CGPoint(x: lBounds.width, y: 0), to: rPresenation)
            let corner3 = layer.convert(CGPoint(x: 0, y: lBounds.height), to: rPresenation)
            
            let tx = corner0.x, ty = corner0.y
            let affineTransform = CGAffineTransform(a: (corner1.x - tx) / max(lBounds.width, 0.0001),
                                                    b: (corner1.y - ty) / max(lBounds.width, 0.0001),
                                                    c: (corner3.x - tx) / max(lBounds.height, 0.0001),
                                                    d: (corner3.y - ty) / max(lBounds.height, 0.0001),
                                                    tx: tx,
                                                    ty: ty).scaledBy(x: scale, y: scale)
            return Mask.affine(rect: lBounds, transform: affineTransform)
        } else {
           // TODO: finish 3D animations
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
