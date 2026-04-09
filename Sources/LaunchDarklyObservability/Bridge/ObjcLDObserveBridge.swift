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
