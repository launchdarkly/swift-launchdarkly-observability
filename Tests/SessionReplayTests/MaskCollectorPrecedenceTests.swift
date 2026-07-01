import Testing
@testable import LaunchDarklySessionReplay
import UIKit

@MainActor
struct MaskCollectorPrecedenceTests {
    typealias Settings = MaskingPolicy
    typealias PrivacyOptions = SessionReplayOptions.PrivacyOptions

    private func makeSettings(_ privacy: PrivacyOptions = PrivacyOptions(maskTextInputs: false)) -> Settings {
        Settings(privacySettings: privacy)
    }

    // MARK: - explicitMaskState (per-view explicit state, ignoring ancestors)

    @Test("explicitMaskState is nil when the view has no rule")
    func explicitMaskStateNoRule() {
        let view = UIView()
        #expect(makeSettings().explicitMaskState(view, viewType: type(of: view)) == nil)
    }

    @Test("explicitMaskState is true after .ldMask()")
    func explicitMaskStateLdMask() {
        let view = UIView()
        view.ldMask()
        #expect(makeSettings().explicitMaskState(view, viewType: type(of: view)) == true)
    }

    @Test("explicitMaskState is true when accessibilityIdentifier matches maskAccessibilityIdentifiers")
    func explicitMaskStateAccessibilityIdMask() {
        let settings = makeSettings(.init(maskTextInputs: false, maskAccessibilityIdentifiers: ["secret"]))
        let view = UIView()
        view.accessibilityIdentifier = "secret"
        #expect(settings.explicitMaskState(view, viewType: type(of: view)) == true)
    }

    @Test("explicitMaskState is true when the view class is in maskUIViews")
    func explicitMaskStateClassMask() {
        let settings = makeSettings(.init(maskTextInputs: false, maskUIViews: [UILabel.self]))
        let view = UILabel()
        #expect(settings.explicitMaskState(view, viewType: type(of: view)) == true)
    }

    @Test("explicitMaskState is false after .ldUnmask()")
    func explicitMaskStateLdUnmask() {
        let view = UIView()
        view.ldUnmask()
        #expect(makeSettings().explicitMaskState(view, viewType: type(of: view)) == false)
    }

    @Test("explicitMaskState is false when accessibilityIdentifier matches unmaskAccessibilityIdentifiers")
    func explicitMaskStateAccessibilityIdUnmask() {
        let settings = makeSettings(.init(maskTextInputs: false, unmaskAccessibilityIdentifiers: ["public"]))
        let view = UIView()
        view.accessibilityIdentifier = "public"
        #expect(settings.explicitMaskState(view, viewType: type(of: view)) == false)
    }

    @Test("explicitMaskState is false when the view class is in unmaskUIViews")
    func explicitMaskStateClassUnmask() {
        let settings = makeSettings(.init(maskTextInputs: false, unmaskUIViews: [UILabel.self]))
        let view = UILabel()
        #expect(settings.explicitMaskState(view, viewType: type(of: view)) == false)
    }

    @Test("explicitMaskState: mask wins over unmask when both apply via different channels")
    func explicitMaskStateMaskWinsOverUnmask() {
        let settings = makeSettings(.init(maskTextInputs: false, unmaskAccessibilityIdentifiers: ["conflict"]))
        let view = UIView()
        view.accessibilityIdentifier = "conflict"
        view.ldMask()
        #expect(settings.explicitMaskState(view, viewType: type(of: view)) == true)
    }

    // MARK: - resolveExplicitMask (combines ancestor state with per-view state)

    @Test("resolveExplicitMask short-circuits to true when an ancestor is masked, even if the view itself is unmasked")
    func resolveAncestorMaskedWins() {
        let view = UIView()
        view.ldUnmask()
        #expect(makeSettings().resolveExplicitMask(view, viewType: type(of: view), inheritedExplicitMask: true) == true)
    }

    @Test("resolveExplicitMask: own mask overrides inherited unmask")
    func resolveOwnMaskOverridesInheritedUnmask() {
        let view = UIView()
        view.ldMask()
        #expect(makeSettings().resolveExplicitMask(view, viewType: type(of: view), inheritedExplicitMask: false) == true)
    }

    @Test("resolveExplicitMask: inherited unmask propagates when the view has no own rule")
    func resolveInheritedUnmaskPropagates() {
        let view = UIView()
        #expect(makeSettings().resolveExplicitMask(view, viewType: type(of: view), inheritedExplicitMask: false) == false)
    }

    // MARK: - shouldMask (final precedence: explicit wins, fall back to global config)

    @Test("shouldMask returns true when the resolved explicit state is true")
    func shouldMaskExplicitMaskWins() {
        let view = UIView()
        let className = NSStringFromClass(type(of: view))
        #expect(makeSettings().shouldMask(view, viewType: type(of: view), className: className, resolvedExplicitMask: true) == true)
    }

    @Test("shouldMask: resolved unmask overrides a global rule that would otherwise mask")
    func shouldMaskExplicitUnmaskOverridesGlobal() {
        let settings = makeSettings(.init(maskLabels: true))
        let view = UILabel()
        let className = NSStringFromClass(type(of: view))
        #expect(settings.shouldMask(view, viewType: type(of: view), className: className, resolvedExplicitMask: false) == false)
    }

    @Test("shouldMask: with no explicit rule, the global config decides")
    func shouldMaskGlobalFallback() {
        let settings = makeSettings(.init(maskLabels: true))
        let view = UILabel()
        let className = NSStringFromClass(type(of: view))
        #expect(settings.shouldMask(view, viewType: type(of: view), className: className, resolvedExplicitMask: nil) == true)
    }

    // MARK: - iOS 26 camera UI (ModeLoupeLayer crash regression)

    @Test("isCameraUIType matches known CameraUI views and layers")
    func matchesKnownCameraUITypes() {
        #expect(MaskingPolicy.Constants.isCameraUIType(className: "CameraUI.ChromeSwiftUIView"))
        #expect(MaskingPolicy.Constants.isCameraUIType(className: "CameraUI.ModeLoupeLayer"))
    }

    @Test("shouldMaskFromGlobalConfig masks iOS26 camera chrome even when privacy toggles are off")
    func masksIOS26CameraChromeRegardlessOfPrivacyToggles() {
        let settings = makeSettings(.init(
            maskTextInputs: false,
            maskWebViews: false,
            maskLabels: false,
            maskImages: false
        ))
        guard let cameraClass = NSClassFromString("CameraUI.ChromeSwiftUIView") else { return }
        let view = (cameraClass as! UIView.Type).init()
        let className = NSStringFromClass(cameraClass)
        #expect(settings.shouldMask(view, viewType: cameraClass, className: className, resolvedExplicitMask: nil) == true)
    }

    @Test("shouldSkipLayer skips any CameraUI-prefixed layer")
    func skipsIOS26CameraLayers() {
        let settings = makeSettings()
        #expect(settings.shouldSkipLayer(className: "CameraUI.ModeLoupeLayer"))
        #expect(settings.shouldSkipLayer(className: "CameraUI.SomeOtherLayer"))
        #expect(settings.shouldSkipLayer(className: NSStringFromClass(type(of: CALayer()))) == false)
    }

    @Test("isCameraUIType matches any CameraUI-prefixed class name")
    func matchesCameraUIPrefix() {
        #expect(MaskingPolicy.Constants.isCameraUIType(className: "CameraUI.UnknownView"))
        #expect(!MaskingPolicy.Constants.isCameraUIType(className: "UIKit.UIView"))
    }
}
