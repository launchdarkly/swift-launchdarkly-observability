import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

final class OtlpMetricScheduleExporter: MetricExporter {
    private let eventQueue: EventQueue
    private let aggregationTemporalitySelector: AggregationTemporalitySelector
    private let defaultAggregationSelector: DefaultAggregationSelector
    
    init(eventQueue: EventQueue,
         aggregationTemporalitySelector: AggregationTemporalitySelector = AggregationTemporality.alwaysCumulative(),
         defaultAggregationSelector: DefaultAggregationSelector = AggregationSelector.instance) {
        self.eventQueue = eventQueue
        self.aggregationTemporalitySelector = aggregationTemporalitySelector
        self.defaultAggregationSelector = defaultAggregationSelector
    }
    
    func export(metrics: [OpenTelemetrySdk.MetricData]) -> OpenTelemetrySdk.ExportResult {
        Task {
            let timestamp = Date().timeIntervalSince1970
            let payloads = metrics.map { MetricItem(metricData: $0, timestamp: timestamp) }
            await self.eventQueue.send(payloads)
        }
        return .success
    }
    
    func flush() -> OpenTelemetrySdk.ExportResult {
        return .success
    }
    
    func shutdown() -> OpenTelemetrySdk.ExportResult {
        return .success
    }
    
    public func getAggregationTemporality(
      for instrument: OpenTelemetrySdk.InstrumentType
    ) -> OpenTelemetrySdk.AggregationTemporality {
      return aggregationTemporalitySelector.getAggregationTemporality(
        for: instrument)
    }

    // MARK: - DefaultAggregationSelector

    public func getDefaultAggregation(
      for instrument: OpenTelemetrySdk.InstrumentType
    ) -> OpenTelemetrySdk.Aggregation {
      return defaultAggregationSelector.getDefaultAggregation(for: instrument)
    }
}
