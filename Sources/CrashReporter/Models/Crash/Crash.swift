import Foundation

// MARK: - Crash
public struct Crash: Codable, Hashable, Sendable {
    public let error: CrashError
    public let threads: [Thread]

    public enum CodingKeys: String, CodingKey {
        case error = "error"
        case threads = "threads"
    }

    public init(error: CrashError, threads: [Thread]) {
        self.error = error
        self.threads = threads
    }
}
