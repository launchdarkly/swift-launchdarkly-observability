import Foundation
import OpenTelemetryApi

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
    ///   - parentSpanId: 16-char hex parent span identifier (empty string for root spans).
    /// - Returns: An ``ObjcSpanBuilder`` wrapping the live span.
    @objc(spanBuilderWithName:startTime:traceId:parentSpanId:)
    public func spanBuilder(name: String,
                            startTime: Double,
                            traceId: String,
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

        let span = builder.startSpan()
        return ObjcSpanBuilder(span: span)
    }
}
