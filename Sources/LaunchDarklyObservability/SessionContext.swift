import Foundation

public struct SessionContext: Encodable, Sendable {
    public let sessionId: String
    public let sessionDuration: TimeInterval
    
    init(sessionId: String, sessionDuration: TimeInterval = .zero) {
        self.sessionId = sessionId
        self.sessionDuration = sessionDuration
    }
}
