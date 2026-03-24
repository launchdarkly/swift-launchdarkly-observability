import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

final class EventSpanProcessor: SpanProcessor {
    private let eventQueue: EventQueue
    private let sampler: ExportSampler
    let isStartRequired = false
    let isEndRequired = true
    
    init(eventQueue: EventQueue, sampler: ExportSampler) {
        self.eventQueue = eventQueue
        self.sampler = sampler
    }
    
    func onStart(parentContext: OpenTelemetryApi.SpanContext?, span: any OpenTelemetrySdk.ReadableSpan) {
        // No-op
    }
    
    func onEnd(span: any OpenTelemetrySdk.ReadableSpan) {
        if !span.context.traceFlags.sampled {
          return
        }
        
        Task {
            var spanData = span.toSpanData()
            spanData = Self.applyBridgeIdOverrides(spanData)
            await send(spans: [spanData])
        }
    }

    /// If the span carries bridge-supplied IDs (set by ``ObjcTracer``),
    /// replace the auto-generated IDs with them and strip the internal attributes.
    private static func applyBridgeIdOverrides(_ data: SpanData) -> SpanData {
        let hasTraceId = data.attributes[bridgeTraceIdAttributeKey] != nil
        let hasSpanId = data.attributes[bridgeSpanIdAttributeKey] != nil
        guard hasTraceId || hasSpanId else { return data }

        var result = data
        if case let .string(hex) = data.attributes[bridgeTraceIdAttributeKey] {
            result.settingTraceId(TraceId(fromHexString: hex))
        }
        if case let .string(hex) = data.attributes[bridgeSpanIdAttributeKey] {
            result.settingSpanId(SpanId(fromHexString: hex))
        }
        var attrs = result.attributes
        attrs.removeValue(forKey: bridgeTraceIdAttributeKey)
        attrs.removeValue(forKey: bridgeSpanIdAttributeKey)
        result.settingAttributes(attrs)
        return result
    }
        
    func send(spans: [SpanData]) async {
        let sampledItems = sampler.sampleSpans(items: spans)
        guard !sampledItems.isEmpty else {
            return
        }

        let items: [SpanItem] = sampledItems.map { SpanItem(spanData: $0) }
        await eventQueue.send(items)
    }
    
    func shutdown(explicitTimeout: TimeInterval?) {
        // No-op
    }
    
    func forceFlush(timeout: TimeInterval?) {
        // No-op
    }
    
   
}
