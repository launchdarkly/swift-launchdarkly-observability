#if canImport(UIKit)
import UIKit
import Testing
@testable import LaunchDarklyObservability

@MainActor
struct LdClickRegistryTests {
    @Test("id returns the id recorded at a matching location")
    func returnsMatchingLocation() {
        let registry = LdClickRegistry()
        registry.record(id: "checkout.pay_button", location: CGPoint(x: 100, y: 200))
        #expect(registry.id(at: CGPoint(x: 100, y: 200)) == "checkout.pay_button")
    }

    @Test("id tolerates small location differences")
    func returnsWithinTolerance() {
        let registry = LdClickRegistry()
        registry.record(id: "id", location: CGPoint(x: 100, y: 100))
        #expect(registry.id(at: CGPoint(x: 110, y: 92)) == "id")
    }

    @Test("id ignores entries far from the touch point")
    func ignoresFarLocation() {
        let registry = LdClickRegistry()
        registry.record(id: "id", location: CGPoint(x: 100, y: 100))
        #expect(registry.id(at: CGPoint(x: 500, y: 500)) == nil)
    }

    @Test("lookup is non-consuming so multiple pipelines can read the same tap")
    func lookupIsNonConsuming() {
        let registry = LdClickRegistry()
        registry.record(id: "id", location: CGPoint(x: 10, y: 10))
        #expect(registry.id(at: CGPoint(x: 10, y: 10)) == "id")
        #expect(registry.id(at: CGPoint(x: 10, y: 10)) == "id")
    }

    @Test("entries without a location match on recency")
    func matchesLocationlessEntry() {
        let registry = LdClickRegistry()
        registry.record(id: "id", location: nil)
        #expect(registry.id(at: CGPoint(x: 42, y: 42)) == "id")
    }

    @Test("the most recent matching entry wins")
    func mostRecentWins() {
        let registry = LdClickRegistry()
        registry.record(id: "old", location: CGPoint(x: 50, y: 50))
        registry.record(id: "new", location: CGPoint(x: 50, y: 50))
        #expect(registry.id(at: CGPoint(x: 50, y: 50)) == "new")
    }

    @Test("an empty id is ignored")
    func ignoresEmptyId() {
        let registry = LdClickRegistry()
        registry.record(id: "", location: CGPoint(x: 1, y: 1))
        #expect(registry.id(at: CGPoint(x: 1, y: 1)) == nil)
    }
}
#endif
