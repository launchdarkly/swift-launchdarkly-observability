import Foundation
import OSLog

public struct SessionOptions: Sendable {
    public let timeout: TimeInterval
    public let isDebug: Bool
    public let log: OSLog

    public init(timeout: TimeInterval, isDebug: Bool = true, log: OSLog) {
        self.timeout = timeout
        self.isDebug = isDebug
        self.log = log
    }
}
