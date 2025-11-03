import Foundation
import OpenTelemetrySdk

public struct MetricItem: EventQueueItemPayload {
    public var exporterClass: AnyClass {
        Observability.OtlpMetricEventExporter.self
    }
    
    public let metric: Metric
    
    public func cost() -> Int {
        300 //+ metric.data.points.count * 100
    }
    
    public var timestamp: TimeInterval  {
        metric.timestamp?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
    }
}
