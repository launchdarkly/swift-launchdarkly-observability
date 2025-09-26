import Foundation
import OSLog
import UIKit

import OpenTelemetrySdk
import OpenTelemetryApi
import OpenTelemetryProtocolExporterHttp
import URLSessionInstrumentation

import API
import Common
import CrashReporter
import CrashReporterLive
import Sampling
import SamplingLive
import Instrumentation

extension Instrumentation {
    static let tracesPath = "/v1/traces"
    static let logsPath = "/v1/logs"
    static let metricsPath = "/v1/metrics"
    
    static func noOp() -> Self {
        Self(
            recordMetric: { _ in },
            recordCount: { _ in },
            recordIncr: { _ in },
            recordHistogram: { _ in },
            recordUpDownCounter: { _ in },
            recordError: { _, _ in },
            recordLog: { _, _, _ in },
            startSpan: { _, _ in
                /// No-op implementation of the Tracer
                DefaultTracer.instance.spanBuilder(spanName: "").startSpan()
            },
            flush: { true }
        )
    }
    
    static func build(
        context: ObservabilityContext,
        sessionManager: SessionManager,
        flushTimeout: TimeInterval = 5.0
    ) throws -> Self {
        let manager = InstrumentationManager(
            context: context,
            sessionManager: sessionManager,
            flushTimeout: flushTimeout
        )
        
        return Self(
            recordMetric: { manager.recordMetric(metric: $0) },
            recordCount: { manager.recordCount(metric: $0) },
            recordIncr: { manager.recordIncr(metric: $0) },
            recordHistogram: { manager.recordHistogram(metric: $0) },
            recordUpDownCounter: { manager.recordUpDownCounter(metric: $0) },
            recordError: { manager.recordError(error: $0, attributes: $1) },
            recordLog: { manager.recordLog(message: $0, severity: $1, attributes: $2) },
            startSpan: { manager.startSpan(name: $0, attributes: $1) },
            flush: { manager.flush() }
        )
    }
}
