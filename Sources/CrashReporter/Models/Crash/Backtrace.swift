import Foundation

// MARK: - Backtrace
public struct Backtrace: Codable, Hashable, Sendable {
    public let contents: [BacktraceContent]
    public let skipped: Int

    public enum CodingKeys: String, CodingKey {
        case contents = "contents"
        case skipped = "skipped"
    }

    public init(contents: [BacktraceContent], skipped: Int) {
        self.contents = contents
        self.skipped = skipped
    }
}
