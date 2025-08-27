import Foundation

// MARK: - Error
public struct CrashError: Codable, Hashable, Sendable {
    public let mach: Mach
    public let signal: Signal
    public let address: Int
    public let type: String

    public enum CodingKeys: String, CodingKey {
        case mach = "mach"
        case signal = "signal"
        case address = "address"
        case type = "type"
    }

    public init(mach: Mach, signal: Signal, address: Int, type: String) {
        self.mach = mach
        self.signal = signal
        self.address = address
        self.type = type
    }
}
