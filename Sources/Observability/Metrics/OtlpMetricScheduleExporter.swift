import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

final class OtlpMetricScheduleExporter: MetricExporter {
    let eventQueue: EventQueue
    
    init(eventQueue: EventQueue) {
        self.eventQueue = eventQueue
    }
    
    func export(metrics: [OpenTelemetrySdk.MetricData]) -> OpenTelemetrySdk.ExportResult {
        return .success
    
        //        Task {
//            await self.eventQueue.send(metrics: metrics)
//        }
    }
    
    func flush() -> OpenTelemetrySdk.ExportResult {
        return .success
    }
    
    func shutdown() -> OpenTelemetrySdk.ExportResult {
        return .success
    }
    
    func getAggregationTemporality(for instrument: OpenTelemetrySdk.InstrumentType) -> OpenTelemetrySdk.AggregationTemporality {
        // no-op
    }
}
