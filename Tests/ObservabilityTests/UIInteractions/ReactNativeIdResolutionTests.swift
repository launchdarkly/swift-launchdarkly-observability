#if canImport(UIKit)
import UIKit
import Testing
@testable import LaunchDarklyObservability

/// Tests for [TargetResolver]'s React Native `nativeID` resolution, which supplies `event.id` for
/// taps in RN apps (set directly or via the RN SDK's `<LDClick id:>` wrapper).
@MainActor
struct ReactNativeIdResolutionTests {
    /// Stand-in for a Paper (old architecture) React Native view: React-Core adds a `nativeID`
    /// category property to `UIView`.
    private final class FakePaperView: UIView {
        @objc var nativeID: String?
    }

    /// Stand-in for a Fabric (new architecture) React Native view: `RCTViewComponentView` exposes a
    /// `nativeId` property.
    private final class FakeFabricView: UIView {
        @objc var nativeId: String?
    }

    private let resolver = TargetResolver()

    @Test("reads a Paper `nativeID` set directly on the hit view")
    func readsPaperNativeID() {
        let view = FakePaperView()
        view.nativeID = "checkout.pay_button"
        #expect(resolver.reactNativeIdWalkingUp(from: view) == "checkout.pay_button")
    }

    @Test("reads a Fabric `nativeId` set directly on the hit view")
    func readsFabricNativeId() {
        let view = FakeFabricView()
        view.nativeId = "checkout.pay_button"
        #expect(resolver.reactNativeIdWalkingUp(from: view) == "checkout.pay_button")
    }

    @Test("walks up to the nearest ancestor carrying a nativeID")
    func walksUpToAncestor() {
        let wrapper = FakePaperView()
        wrapper.nativeID = "card.root"
        let child = UIView()
        wrapper.addSubview(child)
        #expect(resolver.reactNativeIdWalkingUp(from: child) == "card.root")
    }

    @Test("prefers the closest ancestor")
    func prefersClosestAncestor() {
        let outer = FakePaperView()
        outer.nativeID = "card.root"
        let inner = FakePaperView()
        inner.nativeID = "card.cta"
        outer.addSubview(inner)
        let child = UIView()
        inner.addSubview(child)
        #expect(resolver.reactNativeIdWalkingUp(from: child) == "card.cta")
    }

    @Test("returns nil when no view in the chain exposes a nativeID")
    func returnsNilForPlainViews() {
        let parent = UIView()
        let child = UIView()
        parent.addSubview(child)
        #expect(resolver.reactNativeIdWalkingUp(from: child) == nil)
    }

    @Test("ignores an empty nativeID")
    func ignoresEmptyNativeID() {
        let view = FakePaperView()
        view.nativeID = ""
        #expect(resolver.reactNativeIdWalkingUp(from: view) == nil)
    }
}
#endif
