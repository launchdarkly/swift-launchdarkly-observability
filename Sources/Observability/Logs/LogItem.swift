import Foundation
import OpenTelemetrySdk

public struct LogItem: EventQueueItemPayload {
    public var exporterClass: AnyClass {
        OtlpLogExporter.self
    }
    
    public let log: ReadableLogRecord
    
    public func cost() -> Int {
        300 + log.attributes.count * 100
    }
    
    public var timestamp: TimeInterval  {
        log.timestamp.timeIntervalSince1970
    }
}
