import Foundation
import OpenTelemetryApi

@objc(LDObserveBridge)
public final class ObjcLDObserveBridge: NSObject {

    @objc(getObservabilityHookProxy)
    public static func getObservabilityHookProxy() -> ObservabilityHookProxy? {
        guard let service = LDObserve.shared.client as? ObservabilityService else { return nil }
        return ObservabilityHookProxy(exporter: service.hookExporter)
    }

    @objc(getObjcTracer)
    public static func getObjcTracer() -> ObjcTracer? {
        guard let service = LDObserve.shared.client as? ObservabilityService else { return nil }
        return ObjcTracer(tracer: service.tracerDecorator)
    }

    @objc(getObjcLogger)
    public static func getObjcLogger() -> ObjcLogger? {
        guard let service = LDObserve.shared.client as? ObservabilityService else { return nil }
        return ObjcLogger(internalLogger: service.logClient, customerLogger: service.customerLogClient)
    }

    /// Records a custom `track` event. Always broadcasts a Session Replay
    /// `Track` timeline event and, when `analytics.trackEvents` is enabled, emits
    /// the `track` span. `data` carries the optional event payload as a plain
    /// dictionary (e.g. across the Flutter pigeon bridge). `contextKeys` carries
    /// the evaluation context's kind -> key pairs; when supplied they annotate
    /// the `track` span (not the Session Replay `Track` payload), so hosts whose
    /// LaunchDarkly client lives outside this SDK (e.g. Flutter) can attribute
    /// the span to the same context the web SDK records.
    @objc(trackWithKey:data:metricValue:contextKeys:)
    public static func track(key: String, data: [String: Any]?, metricValue: NSNumber?, contextKeys: [String: String]?) {
        guard let contextKeys, !contextKeys.isEmpty,
              let service = LDObserve.shared.client as? ObservabilityService else {
            // No explicit context (or no live service): fall back to the public
            // path, which uses the cached identify context for the span.
            LDObserve.shared.track(key: key, data: data, metricValue: metricValue?.doubleValue)
            return
        }
        var contextKeyAttributes: [String: AttributeValue] = [:]
        for (kind, value) in contextKeys {
            contextKeyAttributes[kind] = .string(value)
        }
        service.track(
            name: key,
            metricValue: metricValue?.doubleValue,
            attributes: data.map { AttributeConverter.convert($0) } ?? [:],
            contextKeyAttributes: contextKeyAttributes
        )
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
        LDObserve.shared.recordError(error, attributes: [:])
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
