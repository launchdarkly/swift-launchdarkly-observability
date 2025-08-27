import Foundation

// MARK: - Memory
public struct Memory: Codable, Hashable, Sendable {
    public let size: Int
    public let usable: Int
    public let free: Int

    public enum CodingKeys: String, CodingKey {
        case size = "size"
        case usable = "usable"
        case free = "free"
    }

    public init(size: Int, usable: Int, free: Int) {
        self.size = size
        self.usable = usable
        self.free = free
    }
}
