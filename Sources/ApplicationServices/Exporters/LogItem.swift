import Foundation
import OpenTelemetrySdk

public struct LogItem: EventQueueItemPayload {
    public let log: ReadableLogRecord
    
    public func cost() -> Int {
        300
    }
}
