import OpenTelemetryApi

import API
import Sampling

public struct Instrumentation {
    public var recordMetric: (_ metric: Metric) -> Void
    public var recordCount: (_ metric: Metric) -> Void
    public var recordIncr: (_ metric: Metric) -> Void
    public var recordHistogram: (_ metric: Metric) -> Void
    public var recordUpDownCounter: (_ metric: Metric) -> Void
    public var recordError: (_ error: Error, _ attributes: [String: AttributeValue]) -> Void
    public var recordLog: (_ message: String, _ severity: Severity, _ attributes: [String: AttributeValue]) -> Void
    public var startSpan: (_ name: String, _ attributes: [String: AttributeValue]) -> Span
    public var flush: () -> Bool
    
    public init(
        recordMetric: @escaping (_: Metric) -> Void,
        recordCount: @escaping (_: Metric) -> Void,
        recordIncr: @escaping (_: Metric) -> Void,
        recordHistogram: @escaping (_: Metric) -> Void,
        recordUpDownCounter: @escaping (_: Metric) -> Void,
        recordError: @escaping (_: Error, _: [String : AttributeValue]) -> Void,
        recordLog: @escaping (_: String, _: Severity, _: [String : AttributeValue]) -> Void,
        startSpan: @escaping (_: String, _: [String : AttributeValue]) -> Span,
        flush: @escaping () -> Bool
    ) {
        self.recordMetric = recordMetric
        self.recordCount = recordCount
        self.recordIncr = recordIncr
        self.recordHistogram = recordHistogram
        self.recordUpDownCounter = recordUpDownCounter
        self.recordError = recordError
        self.recordLog = recordLog
        self.startSpan = startSpan
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

    public func recordError(error: Error, attributes: [String: AttributeValue]) {
        recordError(error, attributes)
    }

    public func recordLog(message: String, severity: Severity, attributes: [String: AttributeValue]) {
        recordLog(message, severity, attributes)
    }

    public func startSpan(name: String, attributes: [String: AttributeValue]) -> Span {
        startSpan(name, attributes)
    }
}
