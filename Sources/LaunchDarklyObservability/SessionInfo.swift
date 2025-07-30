import Foundation

public struct SessionInfo: Sendable, Equatable {
    public let sessionId: String
    public let startTime: TimeInterval
    
    public init(
        sessionId: String = UUID().uuidString,
        startTime: TimeInterval = Date.now.timeIntervalSince1970) {
        self.sessionId = sessionId
        self.startTime = startTime
    }
}
