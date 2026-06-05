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

    @Test("Reset clears history")
    func reset() {
        let stack = ScreenStack()
        _ = stack.record("Home")
        stack.reset()
        #expect(stack.current == nil)
        #expect(stack.record("Profile") == nil)
    }
}
