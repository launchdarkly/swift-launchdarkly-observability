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
            spanData = Self.applyBridgeSpanIdOverride(spanData)
            await send(spans: [spanData])
        }
    }

    /// If the span carries a bridge-supplied span ID (set by ``ObjcTracer``),
    /// replace the auto-generated ID with it and strip the internal attribute.
    private static func applyBridgeSpanIdOverride(_ data: SpanData) -> SpanData {
        guard case let .string(hex) = data.attributes[bridgeSpanIdAttributeKey] else {
            return data
        }
        var result = data
        result.settingSpanId(SpanId(fromHexString: hex))
        var attrs = result.attributes
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
