import Testing
@testable import LaunchDarklySessionReplay
import UIKit

@MainActor
struct MaskCollectorPrecedenceTests {
    typealias Settings = MaskCollector.Settings
    typealias PrivacyOptions = SessionReplayOptions.PrivacyOptions

    private func makeSettings(_ privacy: PrivacyOptions = PrivacyOptions(maskTextInputs: false)) -> Settings {
        Settings(privacySettings: privacy)
    }

    // MARK: - explicitMaskState (per-view explicit state, ignoring ancestors)

    @Test("explicitMaskState is nil when the view has no rule")
    func explicitMaskStateNoRule() {
        #expect(makeSettings().explicitMaskState(UIView()) == nil)
    }

    @Test("explicitMaskState is true after .ldMask()")
    func explicitMaskStateLdMask() {
        let view = UIView()
        view.ldMask()
        #expect(makeSettings().explicitMaskState(view) == true)
    }

    @Test("explicitMaskState is true when accessibilityIdentifier matches maskAccessibilityIdentifiers")
    func explicitMaskStateAccessibilityIdMask() {
        let settings = makeSettings(.init(maskTextInputs: false, maskAccessibilityIdentifiers: ["secret"]))
        let view = UIView()
        view.accessibilityIdentifier = "secret"
        #expect(settings.explicitMaskState(view) == true)
    }

    @Test("explicitMaskState is true when the view class is in maskUIViews")
    func explicitMaskStateClassMask() {
        let settings = makeSettings(.init(maskTextInputs: false, maskUIViews: [UILabel.self]))
        #expect(settings.explicitMaskState(UILabel()) == true)
    }

    @Test("explicitMaskState is false after .ldUnmask()")
    func explicitMaskStateLdUnmask() {
        let view = UIView()
        view.ldUnmask()
        #expect(makeSettings().explicitMaskState(view) == false)
    }

    @Test("explicitMaskState is false when accessibilityIdentifier matches unmaskAccessibilityIdentifiers")
    func explicitMaskStateAccessibilityIdUnmask() {
        let settings = makeSettings(.init(maskTextInputs: false, unmaskAccessibilityIdentifiers: ["public"]))
        let view = UIView()
        view.accessibilityIdentifier = "public"
        #expect(settings.explicitMaskState(view) == false)
    }

    @Test("explicitMaskState is false when the view class is in unmaskUIViews")
    func explicitMaskStateClassUnmask() {
        let settings = makeSettings(.init(maskTextInputs: false, unmaskUIViews: [UILabel.self]))
        #expect(settings.explicitMaskState(UILabel()) == false)
    }

    @Test("explicitMaskState: mask wins over unmask when both apply via different channels")
    func explicitMaskStateMaskWinsOverUnmask() {
        let settings = makeSettings(.init(maskTextInputs: false, unmaskAccessibilityIdentifiers: ["conflict"]))
        let view = UIView()
        view.accessibilityIdentifier = "conflict"
        view.ldMask()
        #expect(settings.explicitMaskState(view) == true)
    }

    // MARK: - resolveExplicitMask (combines ancestor state with per-view state)

    @Test("resolveExplicitMask short-circuits to true when an ancestor is masked, even if the view itself is unmasked")
    func resolveAncestorMaskedWins() {
        let view = UIView()
        view.ldUnmask()
        #expect(makeSettings().resolveExplicitMask(view, inheritedExplicitMask: true) == true)
    }

    @Test("resolveExplicitMask: own mask overrides inherited unmask")
    func resolveOwnMaskOverridesInheritedUnmask() {
        let view = UIView()
        view.ldMask()
        #expect(makeSettings().resolveExplicitMask(view, inheritedExplicitMask: false) == true)
    }

    @Test("resolveExplicitMask: inherited unmask propagates when the view has no own rule")
    func resolveInheritedUnmaskPropagates() {
        #expect(makeSettings().resolveExplicitMask(UIView(), inheritedExplicitMask: false) == false)
    }

    // MARK: - shouldMask (final precedence: explicit wins, fall back to global config)

    @Test("shouldMask returns true when the resolved explicit state is true")
    func shouldMaskExplicitMaskWins() {
        #expect(makeSettings().shouldMask(UIView(), resolvedExplicitMask: true) == true)
    }

    @Test("shouldMask: resolved unmask overrides a global rule that would otherwise mask")
    func shouldMaskExplicitUnmaskOverridesGlobal() {
        let settings = makeSettings(.init(maskLabels: true))
        #expect(settings.shouldMask(UILabel(), resolvedExplicitMask: false) == false)
    }

    @Test("shouldMask: with no explicit rule, the global config decides")
    func shouldMaskGlobalFallback() {
        let settings = makeSettings(.init(maskLabels: true))
        #expect(settings.shouldMask(UILabel(), resolvedExplicitMask: nil) == true)
    }
}
