import Foundation

// MARK: - AppMemory
public struct AppMemory: Codable, Hashable, Sendable {
    public let memoryFootprint: Int
    public let memoryRemaining: Int
    public let memoryPressure: String
    public let memoryLevel: String
    public let memoryLimit: Int
    public let appTransitionState: String

    public enum CodingKeys: String, CodingKey {
        case memoryFootprint = "memory_footprint"
        case memoryRemaining = "memory_remaining"
        case memoryPressure = "memory_pressure"
        case memoryLevel = "memory_level"
        case memoryLimit = "memory_limit"
        case appTransitionState = "app_transition_state"
    }

    public init(memoryFootprint: Int, memoryRemaining: Int, memoryPressure: String, memoryLevel: String, memoryLimit: Int, appTransitionState: String) {
        self.memoryFootprint = memoryFootprint
        self.memoryRemaining = memoryRemaining
        self.memoryPressure = memoryPressure
        self.memoryLevel = memoryLevel
        self.memoryLimit = memoryLimit
        self.appTransitionState = appTransitionState
    }
}
