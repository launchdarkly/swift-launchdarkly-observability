import Foundation
import OpenTelemetryApi

@objc(LDObserveBridge)
public final class ObjcLDObserveBridge: NSObject {

    /// Obj-C friendly entry-point that MAUI can bind to.
    /// - Parameters:
    ///   - message: log message
    ///   - severity: numeric severity (maps to your Swift `Severity(rawValue:)`)
    ///   - attributes: Foundation types only (String, Bool, Int, Double, NSDictionary, NSArray)
    @objc(recordLogWithMessage:severity:attributes:)
    public static func recordLog(message: String,
                                 severity: Int,
                                 attributes: [String: Any] = [:]) {
        let sev = Severity(rawValue: severity) ?? .info
        let attrs = AttributeConverter.convert(attributes)
        LDObserve.shared.recordLog(message: message, severity: sev, attributes: attrs)
    }

    @objc(recordErrorWithMessage:cause:)
    public static func recordError(message: String, cause: String?) {
        let error = NSError(
            domain: "com.launchdarkly.observability",
            code: 0,
            userInfo: [
                NSLocalizedDescriptionKey: message,
                "cause": cause ?? ""
            ]
        )
        LDObserve.shared.recordError(error: error, attributes: [:])
    }

    @objc(recordMetricWithName:value:)
    public static func recordMetric(name: String, value: Double) {
        LDObserve.shared.recordMetric(metric: Metric(name: name, value: value))
    }

    @objc(recordCountWithName:value:)
    public static func recordCount(name: String, value: Double) {
        LDObserve.shared.recordCount(metric: Metric(name: name, value: value))
    }

    @objc(recordIncrWithName:value:)
    public static func recordIncr(name: String, value: Double) {
        LDObserve.shared.recordIncr(metric: Metric(name: name, value: value))
    }

    @objc(recordHistogramWithName:value:)
    public static func recordHistogram(name: String, value: Double) {
        LDObserve.shared.recordHistogram(metric: Metric(name: name, value: value))
    }

    @objc(recordUpDownCounterWithName:value:)
    public static func recordUpDownCounter(name: String, value: Double) {
        LDObserve.shared.recordUpDownCounter(metric: Metric(name: name, value: value))
    }
}
