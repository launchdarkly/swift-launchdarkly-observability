import Foundation
import OpenTelemetryApi

/// @objc adapter that wraps the SDK's logging APIs for the C# / MAUI bridge.
///
/// Mirrors the ``ObjcTracer`` pattern: MAUI obtains an instance via
/// ``ObjcLDObserveBridge/getObjcLogger()`` and calls ``recordLog``
/// directly, letting the log flow through the native sampling and
/// event pipeline.
///
/// Holds two loggers:
/// - ``internalLogger`` (``InternalLogsApi``): bypasses level-gating, supports span context.
/// - ``customerLogger`` (``LogsApi``): level-gated, customer-facing.
@objc(ObjcLogger)
public final class ObjcLogger: NSObject {
    private let internalLogger: InternalLogsApi
    private let customerLogger: LogsApi

    init(internalLogger: InternalLogsApi, customerLogger: LogsApi) {
        self.internalLogger = internalLogger
        self.customerLogger = customerLogger
        super.init()
    }

    /// Records a log through the native pipeline.
    ///
    /// - Parameters:
    ///   - message:    Log body text.
    ///   - severity:   Numeric severity (maps to ``Severity(rawValue:)``).
    ///   - traceId:    32-char hex trace identifier for trace-log correlation, or `nil` when no active span.
    ///   - spanId:     16-char hex span identifier for trace-log correlation, or `nil` when no active span.
    ///   - isInternal: When `true`, dispatches to the internal logger (bypasses level gating, supports span context).
    ///                 When `false`, dispatches to the customer logger (level-gated).
    ///   - attributes: Foundation types only (String, Bool, Int, Double, NSDictionary, NSArray).
    @objc(recordLogWithMessage:severity:traceId:spanId:isInternal:attributes:)
    public func recordLog(message: String,
                          severity: Int,
                          traceId: String?,
                          spanId: String?,
                          isInternal: Bool,
                          attributes: [String: Any]) {
        let sev = Severity(rawValue: severity) ?? .info
        let attrs = AttributeConverter.convert(attributes)

        var spanContext: SpanContext? = nil
        if let traceId, let spanId, !traceId.isEmpty, !spanId.isEmpty {
            spanContext = SpanContext.create(
                traceId: TraceId(fromHexString: traceId),
                spanId: SpanId(fromHexString: spanId),
                traceFlags: TraceFlags().settingIsSampled(true),
                traceState: TraceState()
            )
        }

        if isInternal {
            internalLogger.recordLog(message: message, severity: sev, attributes: attrs, spanContext: spanContext)
        } else {
            customerLogger.recordLog(message: message, severity: sev, attributes: attrs, spanContext: spanContext)
        }
    }
}
