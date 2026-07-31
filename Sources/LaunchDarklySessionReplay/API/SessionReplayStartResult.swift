public enum SessionReplayStartResult: Equatable {
    /// Session Replay was not installed or has not finished registering.
    case unavailable
    /// Session Replay is now running because this call started it.
    case started
    /// Session Replay was already running before this call.
    case alreadyStarted
    /// Session Replay stayed stopped because the session was sampled out.
    case sampledOut
    /// Session Replay stayed stopped because the backend refused this launch in a way retrying cannot
    /// fix. Recording is only attempted again on the next launch, so starting again has no effect.
    case unrecoverableError

    public var isRunning: Bool {
        switch self {
        case .started, .alreadyStarted:
            return true
        case .unavailable, .sampledOut, .unrecoverableError:
            return false
        }
    }
}
