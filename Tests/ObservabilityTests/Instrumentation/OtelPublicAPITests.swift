import Testing
import Foundation
// Deliberately a plain import, and the only one of the SDK modules: this file is the
// compile-time check that `LaunchDarklyOtel` is usable on its own, with the OTel recording
// API reachable through its re-exports rather than through the instrumentation package.
import LaunchDarklyOtel

/// Exercises the public surface a `LaunchDarklyOtel`-only consumer sees. `LDObserve.shared`
/// is the no-op client until a plugin registers, so every call here is inert — the value is
/// in what compiles.
struct OtelPublicAPITests {
    @Test("the plugin can be constructed from options alone")
    func pluginIsConstructible() {
        let plugin = Otel(options: ObservabilityOptions(
            serviceName: "public-api-test",
            otlpEndpoint: "http://127.0.0.1:1",
            backendUrl: "http://127.0.0.1:1"
        ))

        // No pipeline until the plugin registers with an LDClient.
        #expect(plugin.observabilityService == nil)
    }

    @Test("the recording API is reachable without importing OpenTelemetry directly")
    func recordingAPIIsReachable() {
        let observe = LDObserve.shared

        observe.recordLog(message: "hello", severity: .info, attributes: ["k": .string("v")])
        observe.recordLog(message: "hello", severity: .info, properties: ["k": "v"])
        observe.recordError(NSError(domain: "test", code: 1))
        observe.recordMetric(metric: Metric(name: "m", value: 1))
        observe.recordCount(metric: Metric(name: "c", value: 1))
        observe.recordIncr(metric: Metric(name: "i", value: 1))
        observe.recordHistogram(metric: Metric(name: "h", value: 1))
        observe.recordUpDownCounter(metric: Metric(name: "u", value: 1))
        observe.track(key: "purchase", properties: ["sku": "abc"], metricValue: 9.99)
        observe.identify(key: "user-1")
        observe.identify(key: "user-1", attributes: ["plan": "pro"])
        observe.identify(contextKeys: ["user": "user-1"], canonicalKey: "user-1")
        observe.trackScreenView(name: "Home")
        observe.trackClick(id: "cta")

        let span = observe.startSpan(name: "work", properties: ["stage": "load"])
        span.end()
    }
}
