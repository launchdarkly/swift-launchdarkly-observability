import Foundation

// MARK: - Report
public struct Report: Codable, Hashable, Sendable {
    public let version: String
    public let id: String
    public let processName: String
    public let timestamp: String
    public let type: String

    public enum CodingKeys: String, CodingKey {
        case version = "version"
        case id = "id"
        case processName = "process_name"
        case timestamp = "timestamp"
        case type = "type"
    }

    public init(version: String, id: String, processName: String, timestamp: String, type: String) {
        self.version = version
        self.id = id
        self.processName = processName
        self.timestamp = timestamp
        self.type = type
    }
}
