import Foundation
import OpenTelemetrySdk

public struct MetricItem: EventQueueItemPayload {
    public var exporterClass: AnyClass {
        Observability.OtlpMetricEventExporter.self
    }
    
    public let metricData: OpenTelemetrySdk.MetricData
    public var timestamp: TimeInterval
    
    public func cost() -> Int {
        300 //+ metric.data.points.count * 100
    }
}
