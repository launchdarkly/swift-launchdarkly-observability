import Foundation

// MARK: - Signal
public struct Signal: Codable, Hashable, Sendable {
    public let signal: Int
    public let name: String
    public let code: Int
    public let codeName: String

    public enum CodingKeys: String, CodingKey {
        case signal = "signal"
        case name = "name"
        case code = "code"
        case codeName = "code_name"
    }

    public init(signal: Int, name: String, code: Int, codeName: String) {
        self.signal = signal
        self.name = name
        self.code = code
        self.codeName = codeName
    }
}
