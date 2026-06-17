#if canImport(UIKit)
import UIKit
import Testing
@testable import LaunchDarklyObservability

@MainActor
struct LdIdStorageTests {
    @Test("UIView.ldId stores a value retrievable from LdIdStorage")
    func uiViewLdIdStoresValue() {
        let view = UIView()
        view.ldId("checkout.pay_button")
        #expect(LdIdStorage.get(view) == "checkout.pay_button")
    }

    @Test("LdIdStorage returns nil for an untagged view")
    func untaggedViewReturnsNil() {
        let view = UIView()
        #expect(LdIdStorage.get(view) == nil)
    }

    @Test("UIView.ldId overwrites a previously stored value")
    func uiViewLdIdOverwrites() {
        let view = UIView()
        view.ldId("first")
        view.ldId("second")
        #expect(LdIdStorage.get(view) == "second")
    }
}
#endif
