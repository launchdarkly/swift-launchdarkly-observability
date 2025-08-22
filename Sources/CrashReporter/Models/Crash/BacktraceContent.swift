import Foundation

// MARK: - Content
public struct BacktraceContent: Codable, Hashable, Sendable {
    public let objectName: String?
    public let objectAddr: Int?
    public let symbolName: String?
    public let symbolAddr: Int?
    public let instructionAddr: Int

    public enum CodingKeys: String, CodingKey {
        case objectName = "object_name"
        case objectAddr = "object_addr"
        case symbolName = "symbol_name"
        case symbolAddr = "symbol_addr"
        case instructionAddr = "instruction_addr"
    }

    public init(objectName: String?, objectAddr: Int?, symbolName: String?, symbolAddr: Int?, instructionAddr: Int) {
        self.objectName = objectName
        self.objectAddr = objectAddr
        self.symbolName = symbolName
        self.symbolAddr = symbolAddr
        self.instructionAddr = instructionAddr
    }
}
