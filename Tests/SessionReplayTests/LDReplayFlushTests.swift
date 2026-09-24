import Testing
import LaunchDarklyObservability
@testable import LaunchDarklySessionReplay

@Suite("LDReplay.flush", .serialized)
struct LDReplayFlushTests {
    private final class RecordingReplayService: SessionReplayServicing {
        var flushCount = 0
        var isEnabled = false
        var isRunning: Bool { isEnabled }

        func start(ignoreSampling: Bool) -> SessionReplayStartResult { .started }
        func stop() {}
        func flush() async { flushCount += 1 }
        func afterIdentify(contextKeys: [String: String], canonicalKey: String, completed: Bool) {}
        func afterTrack(name: String, metricValue: Double?, attributes: [String: AttributeValue]) {}
    }

    @Test("Forwards to the replay service")
    func forwardsToService() async {
        let service = RecordingReplayService()
        let previous = LDReplay.shared.client
        LDReplay.shared.client = service
        defer { LDReplay.shared.client = previous }

        await LDReplay.shared.flush()

        #expect(service.flushCount == 1)
    }

    @Test("Is a no-op before Session Replay is initialized")
    func noOpWithoutService() async {
        let previous = LDReplay.shared.client
        LDReplay.shared.client = nil
        defer { LDReplay.shared.client = previous }

        await LDReplay.shared.flush()
    }
}
