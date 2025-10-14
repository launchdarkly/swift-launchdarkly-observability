import Foundation

public struct MetricsService {
    public var recordMetric: (_ metric: Metric) -> Void
    public var recordCount: (_ metric: Metric) -> Void
    public var recordIncr: (_ metric: Metric) -> Void
    public var recordHistogram: (_ metric: Metric) -> Void
    public var recordUpDownCounter: (_ metric: Metric) -> Void
    public var flush: () async -> Bool
    
    public init(
        recordMetric: @escaping (_: Metric) -> Void,
        recordCount: @escaping (_: Metric) -> Void,
        recordIncr: @escaping (_: Metric) -> Void,
        recordHistogram: @escaping (_: Metric) -> Void,
        recordUpDownCounter: @escaping (_: Metric) -> Void,
        flush: @escaping () async -> Bool
    ) {
        self.recordMetric = recordMetric
        self.recordCount = recordCount
        self.recordIncr = recordIncr
        self.recordHistogram = recordHistogram
        self.recordUpDownCounter = recordUpDownCounter
        self.flush = flush
    }
    
    public func recordMetric(metric: Metric) {
        recordMetric(metric)
    }

    public func recordCount(metric: Metric) {
        recordCount(metric)
    }

    public func recordIncr(metric: Metric) {
        recordIncr(metric)
    }

    public func recordHistogram(metric: Metric) {
        recordHistogram(metric)
    }

    public func recordUpDownCounter(metric: Metric) {
        recordUpDownCounter(metric)
    }
}
