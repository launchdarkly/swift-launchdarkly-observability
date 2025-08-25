import Foundation

// MARK: - Registers
public struct Registers: Codable, Hashable, Sendable {
    public let basic: [String: Double]
    public let exception: Exception?

    public enum CodingKeys: String, CodingKey {
        case basic = "basic"
        case exception = "exception"
    }

    public init(basic: [String: Double], exception: Exception?) {
        self.basic = basic
        self.exception = exception
    }
}
