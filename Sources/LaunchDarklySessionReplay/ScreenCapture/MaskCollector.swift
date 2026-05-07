import Foundation
#if canImport(WebKit)
import WebKit
#endif
import UIKit
import SwiftUI
#if LD_COCOAPODS
import LaunchDarklyObservability
#else
import Common
#endif

typealias PrivacySettings = SessionReplayOptions.PrivacyOptions

public struct OffsettedArea {
    public var rect: CGRect
    public var offset: CGPoint

    public init(rect: CGRect, offset: CGPoint) {
        self.rect = rect
        self.offset = offset
    }
}

final class MaskCollector {
    enum Constants {
        static let maskiOS26ViewTypes = Set(["CameraUI.ChromeSwiftUIView"])
    }
    
    struct Settings {
        var maskiOS26ViewTypes: Set<String>
        var maskTextInputs: Bool
        var maskLabels: Bool
        var maskWebViews: Bool
        var maskImages: Bool
        var minimumAlpha: Float
        var maximumAlpha: Float
        var maskUIViews: Set<ObjectIdentifier>
        var unmaskUIViews: Set<ObjectIdentifier>
        var ignoreUIViews: Set<ObjectIdentifier>
        
        var maskAccessibilityIdentifiers: Set<String>
        var unmaskAccessibilityIdentifiers: Set<String>
        var ignoreAccessibilityIdentifiers: Set<String>
        
        init(privacySettings: PrivacySettings) {
            self.maskiOS26ViewTypes = Constants.maskiOS26ViewTypes
            self.maskTextInputs = privacySettings.maskTextInputs
            self.maskLabels = privacySettings.maskLabels
            self.maskWebViews = privacySettings.maskWebViews
            self.maskImages = privacySettings.maskImages
            self.minimumAlpha = Float(privacySettings.minimumAlpha)
            self.maximumAlpha = Float(1 - privacySettings.minimumAlpha)
            
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
        
        func isExplicitlyMasked(_ view: UIView) -> Bool {
            if SessionReplayAssociatedObjects.shouldMaskUIView(view) == true {
                return true
            }
            if maskUIViews.contains(ObjectIdentifier(type(of: view))) {
                return true
            }
            if let accessibilityIdentifier = view.accessibilityIdentifier,
               maskAccessibilityIdentifiers.contains(accessibilityIdentifier) {
                return true
            }
            return false
        }

        func isExplicitlyUnmasked(_ view: UIView) -> Bool {
            if SessionReplayAssociatedObjects.shouldMaskUIView(view) == false {
                return true
            }
            if unmaskUIViews.contains(ObjectIdentifier(type(of: view))) {
                return true
            }
            if let accessibilityIdentifier = view.accessibilityIdentifier,
               unmaskAccessibilityIdentifiers.contains(accessibilityIdentifier) {
                return true
            }
            return false
        }

        func shouldMaskFromGlobalConfig(_ view: UIView) -> Bool {
            let stringViewType = String(describing: type(of: view))

            if maskiOS26ViewTypes.contains(stringViewType) {
                return true
            }

            if maskWebViews {
#if canImport(WebKit)
                if view is WKWebView {
                    return true
                }
#endif
            }

            if maskTextInputs {
                if view is UITextInput {
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

            if maskLabels && view is UILabel {
                return true
            }

            if maskImages && view is UIImageView {
                return true
            }

            return false
        }

        /// Returns the explicit mask state of `view` itself, ignoring ancestors:
        /// `true` = explicitly masked, `false` = explicitly unmasked, `nil` = no explicit rule.
        /// Mask wins over unmask when both apply to the same view.
        func explicitMaskState(_ view: UIView) -> Bool? {
            if isExplicitlyMasked(view) {
                return true
            }
            if isExplicitlyUnmasked(view) {
                return false
            }
            return nil
        }

        /// Combines the inherited explicit state from ancestors with `view`'s own explicit state.
        /// Short-circuits when an ancestor is already masked: mask propagation wins outright.
        func resolveExplicitMask(_ view: UIView, inheritedExplicitMask: Bool?) -> Bool? {
            if inheritedExplicitMask == true { return true }
            return explicitMaskState(view) ?? inheritedExplicitMask
        }

        /// Final precedence: an explicit (resolved) state wins; otherwise fall back to global config.
        func shouldMask(_ view: UIView, resolvedExplicitMask: Bool?) -> Bool {
            return resolvedExplicitMask ?? shouldMaskFromGlobalConfig(view)
        }
    }
    
    var settings: Settings
    
    public init(privacySettings: PrivacySettings) {
        self.settings = Settings(privacySettings: privacySettings)
    }
    
    func collectViewMasks(in rootView: UIView, window: UIWindow, scale: CGFloat) -> (maskOperations: [MaskOperation], offsetRects: [OffsettedArea]) {
        var operations = [MaskOperation]()
        var offsetRects = [OffsettedArea]()

        let root = rootView.layer
        let rPresenation = root.presentation() ?? root
        
        func visit(layer: CALayer, inheritedExplicitMask: Bool?) {
            guard let view = layer.delegate as? UIView else { return }
            guard !view.isHidden,
                  view.window != nil,
                  layer.opacity >= settings.minimumAlpha else { return }

            guard !settings.shouldIgnore(view) else { return }

            let effectiveFrame = rPresenation.convert(layer.frame, from: layer.superlayer)

            let resolvedExplicitMask = settings.resolveExplicitMask(view, inheritedExplicitMask: inheritedExplicitMask)
            let shouldMask = settings.shouldMask(view, resolvedExplicitMask: resolvedExplicitMask)
            if shouldMask, let mask = createMask(rPresenation, layer: layer, scale: scale) {
                var operation = MaskOperation(mask: mask, kind: .fill, effectiveFrame: effectiveFrame)
#if DEBUG
                operation.accessibilityIdentifier = view.accessibilityIdentifier
#endif
                operations.append(operation)
                return
            }

            if let scrollView = view as? UIScrollView {
                let offset = scrollView.contentOffset
                if offset.x != 0 || offset.y != 0 {
                    offsetRects.append(OffsettedArea(rect: effectiveFrame, offset: offset))
                }
            }

            if operations.isNotEmpty, !isSystem(view: view, pLayer: layer), !isTransparent(view: view, pLayer: layer) {
                operations.removeAll {
                    effectiveFrame.contains($0.effectiveFrame)
                }
            }

            if let sublayers = layer.sublayers?.sorted(by: { $0.zPosition < $1.zPosition }) {
                sublayers.forEach { visit(layer: $0, inheritedExplicitMask: resolvedExplicitMask) }
            }
        }

        rPresenation.sublayers?.sorted { $0.zPosition < $1.zPosition }.forEach { visit(layer: $0, inheritedExplicitMask: nil) }
        
        return (operations, offsetRects)
    }
    
    func duplicateUnsimilar(before operationsBefore: [MaskOperation], after operationsAfter: [MaskOperation]) -> [MaskOperation]? {
        guard operationsBefore.count == operationsAfter.count else {
            return nil
        }
        
        var result = operationsBefore
        let moveTollerance = 1.0
        let overlapTollerance = 1.1
        for (before, after) in zip(operationsBefore, operationsAfter) {
            let diffX = abs(before.effectiveFrame.minX - after.effectiveFrame.minX)
            let diffY = abs(before.effectiveFrame.minY - after.effectiveFrame.minY)
            
            guard max(diffX, diffY) > moveTollerance else {
                // If movement is present we duplicate the frame
                continue
            }
            
            guard diffX * overlapTollerance < before.effectiveFrame.width - moveTollerance,
                  diffY * overlapTollerance < before.effectiveFrame.height - moveTollerance else {
                // If movement is bigger the size we drop the frame
                return nil
            }
            
            var after = after
            after.kind = .fillDuplicate
            result.append(after)
        }
        
        return result
    }
    
    // this method should be biased into transparency
    private func isTransparent(view: UIView, pLayer: CALayer) -> Bool {
        pLayer.opacity < settings.maximumAlpha
        || view.backgroundColor == nil
        || (view.backgroundColor?.cgColor.alpha ?? 0) < CGFloat(settings.maximumAlpha)
    }
    
    private func isSystem(view: UIView, pLayer: CALayer) -> Bool {
        return false
    }
    
    func createMask(_ rPresenation: CALayer, layer: CALayer, scale: CGFloat) -> Mask? {
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

