import Foundation

// MARK: - Stack
public struct Stack: Codable, Hashable, Sendable {
    public let growDirection: String
    public let dumpStart: Int
    public let dumpEnd: Int
    public let stackPointer: Int
    public let overflow: Bool
    public let contents: String

    public enum CodingKeys: String, CodingKey {
        case growDirection = "grow_direction"
        case dumpStart = "dump_start"
        case dumpEnd = "dump_end"
        case stackPointer = "stack_pointer"
        case overflow = "overflow"
        case contents = "contents"
    }

    public init(growDirection: String, dumpStart: Int, dumpEnd: Int, stackPointer: Int, overflow: Bool, contents: String) {
        self.growDirection = growDirection
        self.dumpStart = dumpStart
        self.dumpEnd = dumpEnd
        self.stackPointer = stackPointer
        self.overflow = overflow
        self.contents = contents
    }
}
