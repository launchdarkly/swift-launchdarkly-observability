import Foundation
import Common

public struct SessionInfo: Sendable, Equatable {
    public let id: String
    public let startTime: Date
    
    public init(id: String, startTime: Date) {
        self.id = id
        self.startTime = startTime
    }
    
    public init() {
        self.init(id: SecureIDGenerator.generateSecureID(), startTime: Date())
    }
    
    var sessionAttributes: [String: AttributeValue] {
        [
            "session.id": .string(id),
            "session.start_time": .string(String(format: "%.0f", startTime.timeIntervalSince1970))
        ]
    }
}
