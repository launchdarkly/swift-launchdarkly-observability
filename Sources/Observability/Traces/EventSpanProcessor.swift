import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

class EventSpanProcessor: SpanProcessor {
    let eventQueue: EventQueue
    let sampler: ExportSampler
    
    init(eventQueue: EventQueue, sampler: ExportSampler) {
        self.eventQueue = eventQueue
        self.sampler = sampler
    }
    
    let isStartRequired = false
    let isEndRequired = true
    
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
