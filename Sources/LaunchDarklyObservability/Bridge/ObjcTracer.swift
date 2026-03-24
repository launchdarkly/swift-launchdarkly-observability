import Foundation
import OpenTelemetryApi

/// Attribute keys used to carry bridge-supplied IDs through the OTel
/// pipeline so ``EventSpanProcessor`` can override the auto-generated
/// IDs before export.
let bridgeTraceIdAttributeKey = "__bridge.trace_id"
let bridgeSpanIdAttributeKey = "__bridge.span_id"

/// @objc adapter that wraps the SDK's ``Tracer`` for the C# / MAUI bridge.
///
/// Returns ``ObjcSpanBuilder`` instances that hold a live span.
/// When the C# side calls ``ObjcSpanBuilder/end(time:)``, the span
/// flows through the normal `onEnd` → `EventSpanProcessor` pipeline.
@objc(ObjcTracer)
public final class ObjcTracer: NSObject {
    private let tracer: any Tracer

    init(tracer: any Tracer) {
        self.tracer = tracer
        super.init()
    }

    /// Creates a new span with the given trace context and returns a builder.
    ///
    /// - Parameters:
    ///   - name:         Operation / display name.
    ///   - startTime:    Span start as epoch seconds.
    ///   - traceId:      32-char hex trace identifier from the .NET Activity.
    ///   - spanId:       16-char hex span identifier from the .NET Activity.
    ///   - parentSpanId: 16-char hex parent span identifier (empty string for root spans).
    /// - Returns: An ``ObjcSpanBuilder`` wrapping the live span.
    @objc(spanBuilderWithName:startTime:traceId:spanId:parentSpanId:)
    public func spanBuilder(name: String,
                            startTime: Double,
                            traceId: String,
                            spanId: String,
                            parentSpanId: String) -> ObjcSpanBuilder {

        let builder = tracer.spanBuilder(spanName: name)
        builder.setStartTime(time: Date(timeIntervalSince1970: startTime))

        if !parentSpanId.isEmpty {
            let parentContext = SpanContext.createFromRemoteParent(
                traceId: TraceId(fromHexString: traceId),
                spanId: SpanId(fromHexString: parentSpanId),
                traceFlags: TraceFlags().settingIsSampled(true),
                traceState: TraceState()
            )
            builder.setParent(parentContext)
        }

        if !traceId.isEmpty {
            builder.setAttribute(key: bridgeTraceIdAttributeKey, value: traceId)
        }
        if !spanId.isEmpty {
            builder.setAttribute(key: bridgeSpanIdAttributeKey, value: spanId)
        }

        let span = builder.startSpan()
        return ObjcSpanBuilder(span: span, bridgeSpanId: spanId)
    }
}
