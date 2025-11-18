#if canImport(UIKit)
import Foundation
import UIKit
import Testing
@testable import LaunchDarklyObservability

@Suite
struct LaunchTrackerReducerTests {

    @Test
    func testColdLaunch() throws {
        var state = LaunchTracker.State()

        // GIVEN: app just started (cold)
        let startUptime: TimeInterval = 1.0
        let endUptime: TimeInterval = 2.0
        let sceneID = "ABC"

        // WHEN: scene enters foreground
        LaunchTracker.reduce(
            state: &state,
            action: .sceneWillEnterForeground(
                .init(sceneID: sceneID, systemUptime: startUptime)
            )
        )

        // THEN: start time should be recorded from AppStartTime.stats.startTime
        #expect(state.sceneStartTimes[sceneID] != nil)

        // WHEN: scene becomes active
        LaunchTracker.reduce(
            state: &state,
            action: .sceneDidBecomeActive(
                .init(sceneID: sceneID, systemUptime: endUptime)
            )
        )

        // THEN: launch info should be added
        #expect(state.buffer.count == 1)

        let launch = try #require(state.buffer.first)
        #expect(launch.type == .cold)
        #expect(launch.start == state.sceneStartTimes[sceneID])
        #expect(launch.end == endUptime)
    }


    @Test
    func testWarmLaunch() throws {
        var state = LaunchTracker.State(hasRecordedColdLaunch: true)

        let startUptime: TimeInterval = 5.0
        let endUptime: TimeInterval = 6.0
        let sceneID = "XYZ"

        // Record start
        LaunchTracker.reduce(
            state: &state,
            action: .sceneWillEnterForeground(
                .init(sceneID: sceneID, systemUptime: startUptime)
            )
        )

        // Record end
        LaunchTracker.reduce(
            state: &state,
            action: .sceneDidBecomeActive(
                .init(sceneID: sceneID, systemUptime: endUptime)
            )
        )

        #expect(state.buffer.count == 1)

        let launch = try #require(state.buffer.first)
        #expect(launch.type == .warm)
        #expect(launch.start == state.sceneStartTimes[sceneID])
        #expect(launch.end == endUptime)
    }


    @Test
    func testSceneStartTimesStoredCorrectly() {
        var state = LaunchTracker.State()
        let sceneID = "123"

        LaunchTracker.reduce(
            state: &state,
            action: .sceneWillEnterForeground(
                .init(sceneID: sceneID, systemUptime: 10.0)
            )
        )

        #expect(state.sceneStartTimes.keys.contains(sceneID))
    }


    @Test
    func testLaunchInfoRemovedByTrace() throws {
        var state = LaunchTracker.State()

        let item = LaunchTracker.LaunchInfo(
            sceneID: "A",
            start: 1.0,
            end: 2.0,
            type: .cold
        )

        state.buffer = [item]

        LaunchTracker.reduce(
            state: &state,
            action: .launchInfoItemsWereTraced([item])
        )

        #expect(state.buffer.isEmpty)
    }
}
#endif
