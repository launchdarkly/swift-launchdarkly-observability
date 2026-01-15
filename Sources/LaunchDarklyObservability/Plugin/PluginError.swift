import Foundation

public enum PluginError: LocalizedError {
    case observabilityInstanceAlreadyExist
    
    public var errorDescription: String? {
        switch self {
        case .observabilityInstanceAlreadyExist:
            return "Observability plugin is already initialized, only a single instance can be initialized at runtime."
        }
    }
}
