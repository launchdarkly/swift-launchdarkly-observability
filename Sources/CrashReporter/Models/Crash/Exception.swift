import Foundation

// MARK: - Exception
public struct Exception: Codable, Hashable, Sendable {
    public let exception: Int
    public let esr: Int
    public let far: Int

    public enum CodingKeys: String, CodingKey {
        case exception = "exception"
        case esr = "esr"
        case far = "far"
    }

    public init(exception: Int, esr: Int, far: Int) {
        self.exception = exception
        self.esr = esr
        self.far = far
    }
}
