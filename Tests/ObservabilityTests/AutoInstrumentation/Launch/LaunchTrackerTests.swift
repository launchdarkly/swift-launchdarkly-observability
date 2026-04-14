#if canImport(UIKit)
import Foundation
import UIKit
import Testing
@testable import LaunchDarklyObservability

@Suite
struct LaunchTrackerReducerTests {

    // MARK: - Cold launch

    @Test
    func testColdLaunch() throws {
        var state = LaunchTracker.State()

        let startUptime: TimeInterval = 1.0
        let endUptime: TimeInterval = 2.0
        let sceneID = "ABC"

        // First willEnterForeground on a fresh state → cold
        LaunchTracker.reduce(
            state: &state,
            action: .sceneWillEnterForeground(.init(sceneID: sceneID, systemUptime: startUptime))
        )

        #expect(state.pendingSceneStarts[sceneID]?.type == .cold)
        #expect(state.pendingSceneStarts[sceneID]?.startTime == startUptime)
        #expect(state.hasRecordedColdLaunch)
        #expect(state.seenSceneIDs.contains(sceneID))

        LaunchTracker.reduce(
            state: &state,
            action: .sceneDidBecomeActive(.init(sceneID: sceneID, systemUptime: endUptime))
        )

        #expect(state.buffer.count == 1)

        let launch = try #require(state.buffer.first)
        #expect(launch.type == .cold)
        #expect(launch.start == startUptime)
        #expect(launch.end == endUptime)

        // Pending entry must be cleared after activation
        #expect(state.pendingSceneStarts[sceneID] == nil)
    }

    // MARK: - Warm launch

    @Test
    func testWarmLaunch() throws {
        // Scene has been seen before → next willEnterForeground is a warm launch
        var state = LaunchTracker.State(
            seenSceneIDs: ["XYZ"],
            hasRecordedColdLaunch: true
        )

        let startUptime: TimeInterval = 5.0
        let endUptime: TimeInterval = 6.0
        let sceneID = "XYZ"

        LaunchTracker.reduce(
            state: &state,
            action: .sceneWillEnterForeground(.init(sceneID: sceneID, systemUptime: startUptime))
        )

        #expect(state.pendingSceneStarts[sceneID]?.type == .warm)

        LaunchTracker.reduce(
            state: &state,
            action: .sceneDidBecomeActive(.init(sceneID: sceneID, systemUptime: endUptime))
        )

        #expect(state.buffer.count == 1)

        let launch = try #require(state.buffer.first)
        #expect(launch.type == .warm)
        #expect(launch.start == startUptime)
        #expect(launch.end == endUptime)
    }

    // MARK: - Scene creation

    @Test
    func testSceneCreationLaunch() throws {
        // App already running (cold launch recorded), a brand-new scene appears
        var state = LaunchTracker.State(
            seenSceneIDs: ["EXISTING"],
            hasRecordedColdLaunch: true
        )

        let startUptime: TimeInterval = 10.0
        let endUptime: TimeInterval = 11.5
        let newSceneID = "NEW"

        LaunchTracker.reduce(
            state: &state,
            action: .sceneWillEnterForeground(.init(sceneID: newSceneID, systemUptime: startUptime))
        )

        #expect(state.pendingSceneStarts[newSceneID]?.type == .sceneCreation)
        #expect(state.seenSceneIDs.contains(newSceneID))

        LaunchTracker.reduce(
            state: &state,
            action: .sceneDidBecomeActive(.init(sceneID: newSceneID, systemUptime: endUptime))
        )

        #expect(state.buffer.count == 1)

        let launch = try #require(state.buffer.first)
        #expect(launch.type == .sceneCreation)
        #expect(launch.start == startUptime)
        #expect(launch.end == endUptime)
    }

    // MARK: - Multiple concurrent scenes

    @Test
    func testMultipleConcurrentScenes() throws {
        var state = LaunchTracker.State()

        // First scene — cold
        LaunchTracker.reduce(state: &state, action: .sceneWillEnterForeground(.init(sceneID: "S1", systemUptime: 1.0)))
        // Second scene appears before the first activates — sceneCreation
        LaunchTracker.reduce(state: &state, action: .sceneWillEnterForeground(.init(sceneID: "S2", systemUptime: 1.2)))

        #expect(state.pendingSceneStarts["S1"]?.type == .cold)
        #expect(state.pendingSceneStarts["S2"]?.type == .sceneCreation)

        // Both activate
        LaunchTracker.reduce(state: &state, action: .sceneDidBecomeActive(.init(sceneID: "S1", systemUptime: 2.0)))
        LaunchTracker.reduce(state: &state, action: .sceneDidBecomeActive(.init(sceneID: "S2", systemUptime: 2.5)))

        #expect(state.buffer.count == 2)
        let types = Set(state.buffer.map(\.type))
        #expect(types.contains(.cold))
        #expect(types.contains(.sceneCreation))
    }

    // MARK: - Duplicate willEnterForeground is a no-op while pending

    @Test
    func testDuplicateWillEnterForegroundIgnoredWhilePending() {
        var state = LaunchTracker.State(
            seenSceneIDs: ["ABC"],
            hasRecordedColdLaunch: true
        )

        LaunchTracker.reduce(state: &state, action: .sceneWillEnterForeground(.init(sceneID: "ABC", systemUptime: 5.0)))
        let firstStartTime = state.pendingSceneStarts["ABC"]?.startTime

        // Fire again before didBecomeActive — must not override the start time
        LaunchTracker.reduce(state: &state, action: .sceneWillEnterForeground(.init(sceneID: "ABC", systemUptime: 9.0)))

        #expect(state.pendingSceneStarts["ABC"]?.startTime == firstStartTime)
    }

    // MARK: - didBecomeActive without preceding willEnterForeground is a no-op

    @Test
    func testDidBecomeActiveWithoutPendingStartIsIgnored() {
        var state = LaunchTracker.State()

        LaunchTracker.reduce(state: &state, action: .sceneDidBecomeActive(.init(sceneID: "ABC", systemUptime: 5.0)))

        #expect(state.buffer.isEmpty)
    }

    // MARK: - Traced items are removed from buffer

    @Test
    func testLaunchInfoRemovedByTrace() throws {
        var state = LaunchTracker.State()

        let item = LaunchTracker.LaunchInfo(sceneID: "A", start: 1.0, end: 2.0, type: .cold)
        state.buffer = [item]

        LaunchTracker.reduce(state: &state, action: .launchInfoItemsWereTraced([item]))

        #expect(state.buffer.isEmpty)
    }

    // MARK: - Full cold → warm lifecycle for the same scene

    @Test
    func testColdThenWarmForSameScene() throws {
        var state = LaunchTracker.State()
        let sceneID = "SCENE"

        // Cold launch
        LaunchTracker.reduce(state: &state, action: .sceneWillEnterForeground(.init(sceneID: sceneID, systemUptime: 1.0)))
        LaunchTracker.reduce(state: &state, action: .sceneDidBecomeActive(.init(sceneID: sceneID, systemUptime: 2.0)))

        #expect(state.buffer.first?.type == .cold)

        // Scene goes background → foreground again
        LaunchTracker.reduce(state: &state, action: .sceneWillEnterForeground(.init(sceneID: sceneID, systemUptime: 100.0)))
        LaunchTracker.reduce(state: &state, action: .sceneDidBecomeActive(.init(sceneID: sceneID, systemUptime: 100.3)))

        #expect(state.buffer.count == 2)
        #expect(state.buffer.last?.type == .warm)
        #expect(state.buffer.last?.start == 100.0)
    }
}
#endif
