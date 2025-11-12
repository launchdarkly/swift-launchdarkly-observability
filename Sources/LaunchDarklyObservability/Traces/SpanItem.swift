import Foundation
import OpenTelemetrySdk

struct SpanItem: EventQueueItemPayload {
    var exporterClass: AnyClass {
        Observability.OtlpTraceEventExporter.self
    }
    
    let spanData: SpanData
    var timestamp: TimeInterval
    
    init(spanData: SpanData) {
        self.spanData = spanData
        self.timestamp = spanData.endTime.timeIntervalSince1970
    }
    
    func cost() -> Int {
        300 + spanData.events.count * 100 + spanData.attributes.count * 100
    }
}
