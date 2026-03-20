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
            let spanData = span.toSpanData()
            await send(spans: [spanData])
        }
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
