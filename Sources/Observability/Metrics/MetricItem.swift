import Foundation
import OpenTelemetrySdk

struct MetricItem: EventQueueItemPayload {
    var exporterClass: AnyClass {
        Observability.OtlpMetricEventExporter.self
    }
    
    let metricData: OpenTelemetrySdk.MetricData
    var timestamp: TimeInterval
    
    func cost() -> Int {
        300 + metricData.data.points.count * 100
    }
}
