import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// The pipeline surface an instrumentation package builds against.
///
/// Instrumentation never constructs exporters, queues or samplers of its own: it reads the
/// already-configured tracer, meter and log recorder from here, so everything it emits goes
/// through the same sampling, session stamping and batching as the manual API.
public protocol ObservabilityRuntime: AnyObject {
    var options: ObservabilityOptions { get }
    var session: SessionManaging { get }
    var appLifecycle: AppLifecycleManaging { get }
    var eventQueue: EventQueue { get }

    /// The session-stamped, sampled tracer backing every span the SDK emits.
    var tracer: Tracer { get }
    /// The meter used for the SDK's own gauges and counters. Bypasses the
    /// ``ObservabilityOptions/metricsApi`` gate, which only governs the customer-facing API.
    var metrics: MetricsApi { get }
    /// The log recorder used for SDK-generated logs (crash reports, memory warnings).
    /// Bypasses the ``ObservabilityOptions/logsApiLevel`` gate, which only governs the
    /// customer-facing API.
    var logs: LogRecording { get }

    /// The active screen at the instant of the call, for correlating an interaction with the
    /// `screen_view` that was on screen when it happened.
    var currentScreen: (id: String?, name: String?) { get }

    /// Builds a log record through the same resource, sampling and session stamping as the
    /// log pipeline, without enqueueing it. For instrumentation that needs to hand a record
    /// to the queue itself.
    func buildLogRecord(
        message: String,
        severity: Severity,
        attributes: [String: AttributeValue],
        spanContext: SpanContext?
    ) -> ReadableLogRecord?

    /// Routes a detected screen into the pipeline's single `screen_view` emitter, so
    /// automatic and manual capture share `previous_screen` resolution and context-key merging.
    func recordScreenView(_ screen: ScreenView)
    /// Routes a lifecycle transition into the pipeline's single app-lifecycle emitter.
    func recordAppLifecycleSignal(_ signal: AppLifecycleSignal)
    /// Routes the one-shot process-launch signal into the pipeline's `app_launch` emitter.
    func recordAppLaunchSignal(_ signal: AppLaunchSignal)
}

/// Records a log directly into the pipeline, bypassing the customer-facing severity gate.
public protocol LogRecording {
    func recordLog(
        message: String,
        severity: Severity,
        attributes: [String: AttributeValue],
        spanContext: SpanContext?
    )
}

extension LogRecording {
    public func recordLog(message: String, severity: Severity, attributes: [String: AttributeValue]) {
        recordLog(message: message, severity: severity, attributes: attributes, spanContext: nil)
    }
}
