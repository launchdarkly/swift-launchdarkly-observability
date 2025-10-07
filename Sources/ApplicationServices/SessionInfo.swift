import Foundation

public struct SessionInfo: Sendable, Equatable {
    public let id: String
    public let startTime: Date
    
    public init(id: String, startTime: Date) {
        self.id = id
        self.startTime = startTime
    }
}
