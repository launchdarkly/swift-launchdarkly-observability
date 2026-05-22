import Foundation
#if canImport(WebKit)
import WebKit
#endif
import UIKit
#if LD_COCOAPODS
import LaunchDarklyObservability
#else
import Common
#endif

/// Pure rule engine that decides whether a given UIView/CALayer should
/// be masked, based on the privacy options the host app configured plus
/// any per-view rules attached via `.ldMask()` / `.ldUnmask()` /
/// `.ldIgnore()` (associated objects), accessibility identifiers, or
/// view-class lists.
///
/// `MaskingPolicy` does not traverse hierarchies — it answers
/// per-element questions. The actual walk lives in `MaskCollector`, and
/// the SwiftUI marker pre-pass lives in `MarkerScanner`. Both call back
/// into a shared `MaskingPolicy` instance.
final class MaskingPolicy {
    enum Constants {
        static let maskiOS26ViewTypes = Set(["CameraUI.ChromeSwiftUIView"])

        // Private UIKit view types SwiftUI uses to render `Text` on iOS <= 18
        // (Core Graphics drawn content). Matching by type name because these
        // classes are not publicly exposed.
        static let swiftUITextViewTypes = Set([
            "CGDrawingView",
            "_UIGraphicsView",
            "SwiftUI.CGDrawingView",
            "SwiftUI._UIGraphicsView",
        ])

        // Private CALayer subclasses SwiftUI uses to render content directly
        // (no backing UIView) starting on iOS 26 "Liquid Glass". Matching by
        // the layer's class name via `String(describing:)`.
        static let swiftUITextLayerTypes = Set([
            "CGDrawingLayer",
            "SwiftUI.CGDrawingLayer",
        ])
        static let swiftUIImageLayerTypes = Set([
            "ImageLayer",
            "ColorShapeLayer",
            "SwiftUI.ImageLayer",
            "SwiftUI.ColorShapeLayer",
        ])
    }

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

    func shouldIgnore(_ view: UIView, viewType: AnyClass) -> Bool {
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

    func isExplicitlyMasked(_ view: UIView, viewType: AnyClass) -> Bool {
        if SessionReplayAssociatedObjects.shouldMaskUIView(view) == true {
            return true
        }
        if maskUIViews.contains(ObjectIdentifier(viewType)) {
            return true
        }
        if let accessibilityIdentifier = view.accessibilityIdentifier,
           maskAccessibilityIdentifiers.contains(accessibilityIdentifier) {
            return true
        }
        return false
    }

    func isExplicitlyUnmasked(_ view: UIView, viewType: AnyClass) -> Bool {
        if SessionReplayAssociatedObjects.shouldMaskUIView(view) == false {
            return true
        }
        if unmaskUIViews.contains(ObjectIdentifier(viewType)) {
            return true
        }
        if let accessibilityIdentifier = view.accessibilityIdentifier,
           unmaskAccessibilityIdentifiers.contains(accessibilityIdentifier) {
            return true
        }
        return false
    }

    func shouldMaskFromGlobalConfig(_ view: UIView, viewType: AnyClass) -> Bool {
        // Cheap concrete-type checks first; these short-circuit the
        // common cases (`UILabel`, `UIImageView`, `WKWebView`, plain
        // `UITextField`/`UITextView`) without ever computing the
        // `String(describing: viewType)` representation.
        if maskWebViews {
#if canImport(WebKit)
            if view is WKWebView {
                return true
            }
#endif
        }

        if maskLabels, view is UILabel {
            return true
        }

        if maskImages, view is UIImageView {
            return true
        }

        // `UITextInput` is a protocol; this check still avoids any
        // string allocation for the vast majority of views (the
        // protocol conformance is implemented in cached witness
        // tables on a small set of UIKit classes).
        //
        // The remaining checks all key off the type's name, so once
        // we've allocated the string for the `WKContentView`
        // discrimination we keep reusing it instead of recomputing.
#if canImport(WebKit)
        let stringViewType: String
        if maskTextInputs, view is UITextInput {
            stringViewType = String(describing: viewType)
            if stringViewType != "WKContentView" {
                return true
            }
        } else {
            stringViewType = String(describing: viewType)
        }
#else
        if maskTextInputs, view is UITextInput {
            return true
        }
        let stringViewType = String(describing: viewType)
#endif

        if Constants.maskiOS26ViewTypes.contains(stringViewType) {
            return true
        }

        if maskTextInputs, stringViewType == "UIKeyboard" {
            return true
        }

        if maskLabels, Constants.swiftUITextViewTypes.contains(stringViewType) {
            return true
        }

        return false
    }

    /// Returns the explicit mask state of `view` itself, ignoring ancestors:
    /// `true` = explicitly masked, `false` = explicitly unmasked, `nil` = no explicit rule.
    /// Mask wins over unmask when both apply to the same view.
    func explicitMaskState(_ view: UIView, viewType: AnyClass) -> Bool? {
        if isExplicitlyMasked(view, viewType: viewType) {
            return true
        }
        if isExplicitlyUnmasked(view, viewType: viewType) {
            return false
        }
        return nil
    }

    /// Combines the inherited explicit state from ancestors with `view`'s own explicit state.
    /// Short-circuits when an ancestor is already masked: mask propagation wins outright.
    func resolveExplicitMask(_ view: UIView, viewType: AnyClass, inheritedExplicitMask: Bool?) -> Bool? {
        if inheritedExplicitMask == true { return true }
        return explicitMaskState(view, viewType: viewType) ?? inheritedExplicitMask
    }

    /// Final precedence: an explicit (resolved) state wins; otherwise fall back to global config.
    func shouldMask(_ view: UIView, viewType: AnyClass, resolvedExplicitMask: Bool?) -> Bool {
        return resolvedExplicitMask ?? shouldMaskFromGlobalConfig(view, viewType: viewType)
    }

    /// Evaluates whether a `CALayer` that has no backing `UIView` should be masked.
    ///
    /// Starting on iOS 26 ("Liquid Glass"), SwiftUI renders `Text`, `Image`, and SF
    /// Symbols directly as private `CALayer` subclasses without wrapping them in
    /// `UIView`s. The usual `shouldMask(_ view:)` path can't see these, so we
    /// match by the layer's class name.
    func shouldMaskLayer(_ layer: CALayer) -> Bool {
        let layerType = String(describing: type(of: layer))
        if maskLabels, Constants.swiftUITextLayerTypes.contains(layerType) {
            return true
        }
        if maskImages, Constants.swiftUIImageLayerTypes.contains(layerType) {
            return true
        }
        return false
    }

    /// Combines the per-view explicit state from associated objects /
    /// configuration with an explicit state inherited from a SwiftUI marker
    /// (`markerMask`) and from ancestors (`inheritedExplicitMask`).
    ///
    /// Mask precedence is preserved: any `true` from any source wins; any
    /// `false` from any source wins over a `nil`.
    func resolveExplicitMaskWithMarker(
        view: UIView,
        viewType: AnyClass,
        inheritedExplicitMask: Bool?,
        markerMask: Bool?
    ) -> Bool? {
        if inheritedExplicitMask == true || markerMask == true { return true }

        let own = explicitMaskState(view, viewType: viewType)
        if own == true { return true }

        return own ?? markerMask ?? inheritedExplicitMask
    }
}
