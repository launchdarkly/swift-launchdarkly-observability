import Foundation

public struct Options: Sendable {
    public enum Environment: String, Hashable, Sendable {
        case debug
    }
    let sessionTimeout: TimeInterval
    let environment: Environment
    
    public init(sessionTimeout: TimeInterval = 30 * 60 * 1000, environment: Options.Environment = .debug) {
        self.sessionTimeout = sessionTimeout
        self.environment = environment
    }
}
