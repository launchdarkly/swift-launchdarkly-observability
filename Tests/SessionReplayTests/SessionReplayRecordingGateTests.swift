import Testing
@testable import LaunchDarklySessionReplay

@Suite("SessionReplayRecordingGate")
struct SessionReplayRecordingGateTests {

    @Test("A launch with no cached failure records from the start")
    func cleanLaunchRecordsImmediately() {
        var gate = SessionReplayRecordingGate(hasCachedFailure: false)

        #expect(gate.isScreenCaptureAllowed)
        #expect(gate.canStartRecording)
        #expect(gate.isAwaitingVerdict == false)

        // The session was accepted, which is what the gate already assumed.
        #expect(gate.apply(.allowed) == SessionReplayRecordingGate.Outcome.none)
        #expect(gate.isScreenCaptureAllowed)
    }

    @Test("A cached failure withholds screenshots until the backend accepts the session")
    func cachedFailureWithholdsUntilAccepted() {
        var gate = SessionReplayRecordingGate(hasCachedFailure: true)

        #expect(gate.isScreenCaptureAllowed == false)
        #expect(gate.canStartRecording)
        #expect(gate.isAwaitingVerdict)

        #expect(gate.apply(.allowed) == .releaseScreenCapture)
        #expect(gate.isScreenCaptureAllowed)
        #expect(gate.isAwaitingVerdict == false)

        // Later sessions initialize too; the failure is already cleared, so there is nothing to do.
        #expect(gate.apply(.allowed) == SessionReplayRecordingGate.Outcome.none)
    }

    @Test("A refusal ends recording for the launch")
    func refusalEndsRecording() {
        var gate = SessionReplayRecordingGate(hasCachedFailure: false)

        #expect(gate.apply(.unrecoverable(reason: "blocked")) == .stopRecording(reason: "blocked"))
        #expect(gate.isScreenCaptureAllowed == false)
        #expect(gate.canStartRecording == false)
        // Nothing is owed anymore: the exporter stops talking to the backend until the next launch.
        #expect(gate.isAwaitingVerdict == false)

        #expect(gate.apply(.unrecoverable(reason: "blocked again")) == SessionReplayRecordingGate.Outcome.none)
    }

    @Test("A refusal after a recovery still ends recording")
    func refusalAfterRecovery() {
        var gate = SessionReplayRecordingGate(hasCachedFailure: true)
        #expect(gate.apply(.allowed) == .releaseScreenCapture)

        #expect(gate.apply(.unrecoverable(reason: "blocked")) == .stopRecording(reason: "blocked"))
        #expect(gate.isScreenCaptureAllowed == false)
        #expect(gate.canStartRecording == false)
    }

    @Test("An acceptance after a refusal cannot resume recording")
    func acceptanceAfterRefusalIsIgnored() {
        var gate = SessionReplayRecordingGate(hasCachedFailure: true)
        #expect(gate.apply(.unrecoverable(reason: "blocked")) == .stopRecording(reason: "blocked"))

        #expect(gate.apply(.allowed) == SessionReplayRecordingGate.Outcome.none)
        #expect(gate.isScreenCaptureAllowed == false)
        #expect(gate.canStartRecording == false)
    }
}
