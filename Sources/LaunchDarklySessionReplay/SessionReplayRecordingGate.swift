/// Decides whether Session Replay may take screenshots, from the recording verdicts seen during this
/// launch and the unrecoverable failure cached from a previous one.
///
/// Kept as a value type (like ``SessionReplaySamplingSession``) so the orderings that matter — a refusal
/// arriving before `start()`, a launch that begins with screenshots withheld, a refusal after a
/// recovery — are testable without a live service.
struct SessionReplayRecordingGate {
    /// What the owning service must do in response to a verdict.
    enum Outcome: Equatable {
        /// Nothing to do: the verdict confirms the state the gate is already in.
        case none
        /// Screenshots were withheld and may now start. The cached failure is resolved, so it must be
        /// erased for the next launch to record from the start.
        case releaseScreenCapture
        /// Recording must end for this launch, and `reason` must be persisted so the next launch
        /// withholds screenshots until the backend has answered.
        case stopRecording(reason: String)
    }

    /// Whether screenshots are being held back until the backend accepts the session. Starts out set
    /// when a previous launch was refused.
    private var isWithheld: Bool
    private var hasFailedUnrecoverably = false

    init(hasCachedFailure: Bool) {
        self.isWithheld = hasCachedFailure
    }

    /// Screenshots are taken from the start unless a previous launch was refused, in which case the
    /// backend has to accept the session first.
    var isScreenCaptureAllowed: Bool {
        !hasFailedUnrecoverably && !isWithheld
    }

    /// Whether recording can start at all. A refused launch cannot record again: the exporter stops
    /// talking to the backend until the process is relaunched.
    var canStartRecording: Bool {
        !hasFailedUnrecoverably
    }

    /// Whether a verdict is still owed while screenshots are withheld, which makes a foreground worth
    /// another attempt.
    var isAwaitingVerdict: Bool {
        !hasFailedUnrecoverably && isWithheld
    }

    mutating func apply(_ verdict: SessionReplayInitializationVerdict) -> Outcome {
        switch verdict {
        case .allowed:
            // A refusal is final for this launch, and an acceptance changes nothing when screenshots
            // are already being taken.
            guard !hasFailedUnrecoverably, isWithheld else { return .none }
            isWithheld = false
            return .releaseScreenCapture
        case .unrecoverable(let reason):
            guard !hasFailedUnrecoverably else { return .none }
            hasFailedUnrecoverably = true
            isWithheld = true
            return .stopRecording(reason: reason)
        }
    }
}
