import Foundation

// MARK: - ApplicationStats
public struct ApplicationStats: Codable, Hashable, Sendable {
    public let applicationActive: Bool
    public let applicationInForeground: Bool
    public let launchesSinceLastCrash: Int
    public let sessionsSinceLastCrash: Int
    public let activeTimeSinceLastCrash: Double
    public let backgroundTimeSinceLastCrash: Double
    public let sessionsSinceLaunch: Int
    public let activeTimeSinceLaunch: Double
    public let backgroundTimeSinceLaunch: Double

    public enum CodingKeys: String, CodingKey {
        case applicationActive = "application_active"
        case applicationInForeground = "application_in_foreground"
        case launchesSinceLastCrash = "launches_since_last_crash"
        case sessionsSinceLastCrash = "sessions_since_last_crash"
        case activeTimeSinceLastCrash = "active_time_since_last_crash"
        case backgroundTimeSinceLastCrash = "background_time_since_last_crash"
        case sessionsSinceLaunch = "sessions_since_launch"
        case activeTimeSinceLaunch = "active_time_since_launch"
        case backgroundTimeSinceLaunch = "background_time_since_launch"
    }

    public init(applicationActive: Bool, applicationInForeground: Bool, launchesSinceLastCrash: Int, sessionsSinceLastCrash: Int, activeTimeSinceLastCrash: Double, backgroundTimeSinceLastCrash: Double, sessionsSinceLaunch: Int, activeTimeSinceLaunch: Double, backgroundTimeSinceLaunch: Double) {
        self.applicationActive = applicationActive
        self.applicationInForeground = applicationInForeground
        self.launchesSinceLastCrash = launchesSinceLastCrash
        self.sessionsSinceLastCrash = sessionsSinceLastCrash
        self.activeTimeSinceLastCrash = activeTimeSinceLastCrash
        self.backgroundTimeSinceLastCrash = backgroundTimeSinceLastCrash
        self.sessionsSinceLaunch = sessionsSinceLaunch
        self.activeTimeSinceLaunch = activeTimeSinceLaunch
        self.backgroundTimeSinceLaunch = backgroundTimeSinceLaunch
    }
}
