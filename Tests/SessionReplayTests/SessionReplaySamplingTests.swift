import Testing
@testable import LaunchDarklySessionReplay

struct SessionReplaySamplingTests {
    @Test("sampleRate defaults to always sample")
    func sampleRateDefaultsToAlwaysSample() {
        #expect(SessionReplayOptions().sampleRate == 1.0)
        #expect(SessionReplaySampling.shouldSample(sampleRate: 1.0, randomValue: { 0.99 }))
    }

    @Test("sampleRate zero disables session replay")
    func sampleRateZeroDisablesSessionReplay() {
        #expect(SessionReplaySampling.shouldSample(sampleRate: 0.0, randomValue: { 0.0 }) == false)
    }

    @Test("sampleRate samples when random value is below rate")
    func sampleRateSamplesBelowRate() {
        #expect(SessionReplaySampling.shouldSample(sampleRate: 0.5, randomValue: { 0.49 }))
        #expect(SessionReplaySampling.shouldSample(sampleRate: 0.5, randomValue: { 0.5 }) == false)
    }

    @Test("start result indicates whether session replay is running")
    func startResultIndicatesRunningState() {
        #expect(SessionReplayStartResult.started.isRunning)
        #expect(SessionReplayStartResult.alreadyStarted.isRunning)
        #expect(SessionReplayStartResult.sampledOut.isRunning == false)
        #expect(SessionReplayStartResult.unavailable.isRunning == false)
    }

    @Test("sampling decision is not re-evaluated after sampled out")
    func samplingDecisionIsPersistedUntilReset() {
        var session = SessionReplaySamplingSession()
        #expect(session.shouldStartCapture(ignoreSampling: false, sampleRate: 0.25, randomValue: { 0.99 }) == false)
        #expect(session.shouldStartCapture(ignoreSampling: false, sampleRate: 0.25, randomValue: { 0.0 }) == false)
        session.reset()
        let startedAfterReset = session.shouldStartCapture(ignoreSampling: false, sampleRate: 0.25, randomValue: { 0.0 })
        #expect(startedAfterReset)
    }

    @Test("ignoreSampling bypasses persisted sampled-out decision")
    func ignoreSamplingBypassesPersistedDecision() {
        var session = SessionReplaySamplingSession()
        #expect(session.shouldStartCapture(ignoreSampling: false, sampleRate: 0.25, randomValue: { 0.99 }) == false)
        let startedIgnoringSampling = session.shouldStartCapture(ignoreSampling: true, sampleRate: 0.25, randomValue: { 0.99 })
        #expect(startedIgnoringSampling)
    }
}
