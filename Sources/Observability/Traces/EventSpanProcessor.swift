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
        
        let spanData = span.toSpanData()
        let sampledItems = sampler.sampleSpans(items: [spanData])
        guard !sampledItems.isEmpty else {
            return
        }
        
        Task {
            await eventQueue.send(SpanItem(spanData: spanData))
        }
    }
    
    func shutdown(explicitTimeout: TimeInterval?) {
        // No-op
    }
    
    func forceFlush(timeout: TimeInterval?) {
        // No-op
    }
    
   
}
