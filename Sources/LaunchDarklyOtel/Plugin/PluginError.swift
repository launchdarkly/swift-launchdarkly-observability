import Foundation

public enum PluginError: LocalizedError {
    case observabilityInstanceAlreadyExist
    case sessionReplayInstanceAlreadyExist
    
    public var errorDescription: String? {
        switch self {
        case .observabilityInstanceAlreadyExist:
            return "Observability plugin is already initialized, only a single instance can be initialized at runtime."
        case .sessionReplayInstanceAlreadyExist:
            return "Session Replay plugin is already initialized, only a single instance can be initialized at runtime."
        }
    }
}
