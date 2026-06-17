import Testing
@testable import LaunchDarklyObservability

struct ScreenStackTests {
    @Test("First record has no previous screen")
    func firstRecordHasNoPrevious() {
        let stack = ScreenStack()
        #expect(stack.record("Home") == nil)
        #expect(stack.current == "Home")
    }

    @Test("Sequential records resolve previous screen")
    func sequentialRecords() {
        let stack = ScreenStack()
        #expect(stack.record("Home") == nil)
        #expect(stack.record("Profile") == "Home")
        #expect(stack.record("Settings") == "Profile")
        #expect(stack.snapshot == ["Home", "Profile", "Settings"])
    }

    @Test("Re-appearance of the top screen keeps previous stable")
    func reappearanceOfTop() {
        let stack = ScreenStack()
        _ = stack.record("Home")
        _ = stack.record("Profile")
        #expect(stack.record("Profile") == "Home")
        #expect(stack.snapshot == ["Home", "Profile"])
    }

    @Test("Returning to an earlier screen pops back to it")
    func popBack() {
        let stack = ScreenStack()
        _ = stack.record("Home")
        _ = stack.record("Profile")
        _ = stack.record("Settings")
        #expect(stack.record("Home") == "Settings")
        #expect(stack.snapshot == ["Home"])
        #expect(stack.record("Profile") == "Home")
    }

    @Test("Same name with distinct ids are treated as separate screens")
    func sameNameDistinctIds() {
        let stack = ScreenStack()
        #expect(stack.record("Detail", id: "item-1") == nil)
        // Same display name but a different id is a real navigation, not a re-appearance.
        #expect(stack.record("Detail", id: "item-2") == "Detail")
        #expect(stack.snapshot == ["Detail", "Detail"])
    }

    @Test("Re-appearance keyed by id keeps history stable")
    func reappearanceById() {
        let stack = ScreenStack()
        _ = stack.record("Home", id: "home")
        _ = stack.record("Detail", id: "item-1")
        // The same id re-appears (e.g. UIKit re-show); no navigation occurred.
        #expect(stack.record("Detail", id: "item-1") == "Home")
        #expect(stack.snapshot == ["Home", "Detail"])
    }

    @Test("Pop-back matches by id")
    func popBackById() {
        let stack = ScreenStack()
        _ = stack.record("Detail", id: "item-1")
        _ = stack.record("Detail", id: "item-2")
        _ = stack.record("Detail", id: "item-3")
        // Returning to item-1 pops everything above it (matched by id); previous is the
        // screen we came from, and the stack is trimmed back down to a single entry.
        #expect(stack.record("Detail", id: "item-1") == "Detail")
        #expect(stack.snapshot == ["Detail"])
    }

    @Test("Reset clears history")
    func reset() {
        let stack = ScreenStack()
        _ = stack.record("Home")
        stack.reset()
        #expect(stack.current == nil)
        #expect(stack.record("Profile") == nil)
    }

    @Test("currentId reflects the most recent screen id")
    func currentIdTracksTop() {
        let stack = ScreenStack()
        _ = stack.record("Home", id: "home")
        #expect(stack.currentId == "home")
        _ = stack.record("Detail", id: "item-1")
        #expect(stack.currentId == "item-1")
    }

    @Test("currentId is nil when the current screen has no id")
    func currentIdNilWithoutId() {
        let stack = ScreenStack()
        _ = stack.record("Home")
        #expect(stack.currentId == nil)
    }

    @Test("currentId follows pop-back to the earlier screen's id")
    func currentIdAfterPopBack() {
        let stack = ScreenStack()
        _ = stack.record("Home", id: "home")
        _ = stack.record("Detail", id: "item-1")
        _ = stack.record("More", id: "more")
        _ = stack.record("Home", id: "home")
        #expect(stack.currentId == "home")
    }

    @Test("currentId is nil after reset")
    func currentIdNilAfterReset() {
        let stack = ScreenStack()
        _ = stack.record("Home", id: "home")
        stack.reset()
        #expect(stack.currentId == nil)
    }
}
