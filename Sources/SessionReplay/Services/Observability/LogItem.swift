import Foundation
import OpenTelemetrySdk


struct LogItem: EventQueueItemPayload {
    let log: ReadableLogRecord
    
    func cost() -> Int {
        300
    }
}
