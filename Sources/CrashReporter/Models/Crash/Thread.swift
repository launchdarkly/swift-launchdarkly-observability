import Foundation

// MARK: - Thread
public struct Thread: Codable, Hashable, Sendable {
    public let backtrace: Backtrace
    public let registers: Registers?
    public let index: Int
    public let state: String
    public let crashed: Bool
    public let currentThread: Bool
    public let stack: Stack?
    public let name: String?

    public enum CodingKeys: String, CodingKey {
        case backtrace = "backtrace"
        case registers = "registers"
        case index = "index"
        case state = "state"
        case crashed = "crashed"
        case currentThread = "current_thread"
        case stack = "stack"
        case name = "name"
    }

    public init(backtrace: Backtrace, registers: Registers?, index: Int, state: String, crashed: Bool, currentThread: Bool, stack: Stack?, name: String?) {
        self.backtrace = backtrace
        self.registers = registers
        self.index = index
        self.state = state
        self.crashed = crashed
        self.currentThread = currentThread
        self.stack = stack
        self.name = name
    }
}
