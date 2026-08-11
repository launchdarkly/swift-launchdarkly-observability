import Foundation
import LaunchDarkly
import LaunchDarklyOtel

enum Failure: LocalizedError {
    case recorded

    var errorDescription: String? {
        "iOS: Manual error - recorded through the OTel-only API"
    }
}

/// One line in the in-app activity feed. The feed is a convenience for manual testing: it says
/// what the app asked the SDK to record, so you know what to look for in the backend.
struct ActivityEntry: Identifiable {
    let id = UUID()
    let time = Date()
    let text: String
}

final class OtelMenuViewModel: ObservableObject {
    @Published private(set) var activity: [ActivityEntry] = []

    private var screenViewCounter = 0
    private var clickCounter = 0

    /// The session every signal is stamped with. Present once the plugin has registered, and it
    /// rotates after the app has been backgrounded past `sessionBackgroundTimeout`.
    var sessionId: String? {
        LDObserve.shared.context?.sessionManager.sessionInfo.id
    }

    // MARK: - Logs

    func recordLog() {
        LDObserve.shared.recordLog(message: "otel-test-app-log", severity: .info, properties: [
            "test-string": "swift",
            "test-true": true,
            "test-integer": 42,
            "test-long": 9_000_000_000,
            "test-double": 3.14,
            "test-array": [3.14],
            "test-nested": ["array": [1]]
        ])
        note("recordLog(severity: .info)")
    }

    func recordWarning() {
        LDObserve.shared.recordLog(message: "otel-test-app-warning", severity: .warn)
        note("recordLog(severity: .warn)")
    }

    /// Logs emitted off the calling thread lose the ambient OTel context, so the span context is
    /// captured up front and passed explicitly to keep the log correlated with its trace.
    func recordLogWithSpanContext() {
        let span = LDObserve.shared.startSpan(name: "log-context-demo", properties: ["demo": "log-with-context"])
        let capturedContext = span.context
        span.end()

        DispatchQueue.global(qos: .background).async {
            LDObserve.shared.recordLog(
                message: "Log with span context",
                severity: .warn,
                properties: ["source": "detached-queue-demo"],
                spanContext: capturedContext
            )
            self.note("recordLog(spanContext:) on a background queue")
        }
    }

    func recordError() {
        LDObserve.shared.recordError(Failure.recorded)
        note("recordError()")
    }

    // MARK: - Traces

    func recordSpan() {
        let span = LDObserve.shared.startSpan(name: "button-pressed", properties: ["source": "otel-test-app"])
        span.end()
        note("startSpan(\"button-pressed\")")
    }

    /// Also exercises the flag-evaluation hook, which the OTel-only plugin keeps: the evaluation
    /// should land as an event on the surrounding span.
    func recordSpanAndVariation() {
        let span = LDObserve.shared.startSpan(name: "span-and-flag-eval")
        _ = LDClient.get()?.boolVariation(forKey: "feature1", defaultValue: false)
        span.end()
        note("startSpan() + boolVariation(\"feature1\")")
    }

    /// Each span is made the active one for the duration of its closure, which is what gives the
    /// inner spans (and the log and count at the bottom) their parent.
    func recordNestedSpans() {
        let outer = LDObserve.shared.startSpan(name: "NestedSpan", properties: ["test-double": 3.14])
        OpenTelemetry.instance.contextProvider.withActiveSpan(outer) {
            let middle = LDObserve.shared.startSpan(name: "NestedSpan1")
            OpenTelemetry.instance.contextProvider.withActiveSpan(middle) {
                let inner = LDObserve.shared.startSpan(name: "NestedSpan2")
                OpenTelemetry.instance.contextProvider.withActiveSpan(inner) {
                    LDObserve.shared.recordCount(metric: .init(name: "NestedCounter", value: 10.0))
                    LDObserve.shared.recordLog(message: "NestedLog", severity: .info)
                    inner.end()
                }
                middle.end()
            }
            outer.end()
        }
        note("3 nested spans, with a log and a count inside")
    }

    // MARK: - Metrics

    func recordMetric() {
        LDObserve.shared.recordMetric(metric: .init(name: "test-gauge", value: 50.0))
        note("recordMetric(\"test-gauge\")")
    }

    func recordHistogram() {
        LDObserve.shared.recordHistogram(metric: .init(name: "test-histogram", value: 15.0))
        note("recordHistogram(\"test-histogram\")")
    }

    func recordCount() {
        LDObserve.shared.recordCount(metric: .init(name: "test-counter", value: 10.0))
        note("recordCount(\"test-counter\")")
    }

    func recordIncr() {
        LDObserve.shared.recordIncr(metric: .init(name: "test-incremental-counter", value: 12.0))
        note("recordIncr(\"test-incremental-counter\")")
    }

    func recordUpDownCounter() {
        LDObserve.shared.recordUpDownCounter(metric: .init(name: "test-up-down-counter", value: 25.0))
        note("recordUpDownCounter(\"test-up-down-counter\")")
    }

    // MARK: - Analytics

    func trackViaLDObserve() {
        LDObserve.shared.track(key: "track-via-ld-observe", properties: [
            "test-string": "ios",
            "test-true": true,
            "test-integer": 42,
            "test-long": 9_000_000_000_123,
            "test-double": 3.14
        ])
        note("LDObserve.track(\"track-via-ld-observe\")")
    }

    /// The `afterTrack` hook is part of the plugin, so events tracked through the LaunchDarkly
    /// client become `track` spans here too.
    func trackViaLDClient() {
        LDClient.get()?.track(key: "track-via-ld-client", data: [
            "test-string": "ios",
            "test-true": true,
            "test-integer": .number(42),
            "test-double": 3.14
        ])
        note("LDClient.track(\"track-via-ld-client\") via the afterTrack hook")
    }

    func trackScreenView() {
        screenViewCounter += 1
        LDObserve.shared.trackScreenView(
            name: "Manual Demo Screen \(screenViewCounter)",
            screenClass: "OtelMenuView",
            screenId: "otel-menu-demo-\(screenViewCounter)",
            category: "Demo",
            properties: ["source": "manual-demo", "index": screenViewCounter]
        )
        note("trackScreenView(\"Manual Demo Screen \(screenViewCounter)\")")
    }

    func trackClick() {
        clickCounter += 1
        LDObserve.shared.trackClick(
            id: "manual-click-\(clickCounter)",
            tag: "Button",
            text: "Track Click"
        )
        note("trackClick(\"manual-click-\(clickCounter)\")")
    }

    // MARK: - Identify

    func identifyUser() {
        var builder = LDContextBuilder(key: "single-userkey")
        builder.kind("user")
        builder.trySetValue("firstName", "Bob")
        builder.trySetValue("lastName", "Bobberson")
        identify(builder.build(), as: "user")
    }

    func identifyAnonymous() {
        var builder = LDContextBuilder()
        builder.anonymous(true)
        identify(builder.build(), as: "anonymous")
    }

    func identifyMulti() {
        var userBuilder = LDContextBuilder(key: "multi-username")
        userBuilder.kind("user")
        userBuilder.name("multi-username")
        userBuilder.trySetValue("email", "multi@multi.com")

        var deviceBuilder = LDContextBuilder(key: "iphone")
        deviceBuilder.kind("device")
        deviceBuilder.trySetValue("platform", .string("ios"))

        guard let user = try? userBuilder.build().get(),
              let device = try? deviceBuilder.build().get() else { return }

        var multiBuilder = LDMultiContextBuilder()
        multiBuilder.addContext(user)
        multiBuilder.addContext(device)
        identify(multiBuilder.build(), as: "multi")
    }

    private func identify(_ result: Result<LDContext, ContextBuilderError>, as description: String) {
        guard let context = try? result.get() else { return }
        LDClient.get()?.identify(context: context) { _ in }
        note("identify(\(description))")
    }

    func clearActivity() {
        activity.removeAll()
    }

    private func note(_ text: String) {
        DispatchQueue.main.async {
            self.activity.insert(ActivityEntry(text: text), at: 0)
        }
    }
}
