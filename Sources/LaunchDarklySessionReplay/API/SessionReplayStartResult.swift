public enum SessionReplayStartResult: Equatable {
    /// Session Replay was not installed or has not finished registering.
    case unavailable
    /// Session Replay is now running because this call started it.
    case started
    /// Session Replay was already running before this call.
    case alreadyStarted
    /// Session Replay stayed stopped because the session was sampled out.
    case sampledOut

    public var isRunning: Bool {
        switch self {
        case .started, .alreadyStarted:
            return true
        case .unavailable, .sampledOut:
            return false
        }
    }
}
