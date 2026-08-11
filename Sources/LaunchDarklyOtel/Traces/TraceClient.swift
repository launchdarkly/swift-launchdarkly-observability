import Foundation.NSDate

final class TraceClient: TracesApi {
    private let options: ObservabilityOptions.AppTracing
    private let tracer: Tracer
    
    init(options: ObservabilityOptions.AppTracing, tracer: Tracer) {
        self.options = options
        self.tracer = tracer
    }
    
    func recordError(_ error: any Error, attributes: [String : AttributeValue]) {
        let builder = tracer.spanBuilder(spanName: "highlight.error")
    
        attributes.forEach {
            builder.setAttribute(key: $0.key, value: $0.value)
        }

        let span = builder.startSpan()
        span.setAttributes(attributes)
        span.recordException(SpanError(error: error), attributes: attributes)
        span.end()
    }
    
    func startSpan(name: String, attributes: [String : AttributeValue]) -> any Span {
        let builder = tracer.spanBuilder(spanName: name)
        attributes.forEach {
            builder.setAttribute(key: $0.key, value: $0.value)
        }
        
        let span = builder.startSpan()
        return span
    }

    /// Starts a span with an explicit kind. Used for the few spans that must not use the
    /// default `.client` kind (e.g. flag evaluations, which are `.internal`).
    func startSpan(name: String, attributes: [String : AttributeValue], spanKind: SpanKind) -> any Span {
        let builder = tracer.spanBuilder(spanName: name)
        builder.setSpanKind(spanKind: spanKind)
        attributes.forEach {
            builder.setAttribute(key: $0.key, value: $0.value)
        }

        let span = builder.startSpan()
        return span
    }
}

/// Internal method used to set span start date
extension TraceClient {
    func startSpan(name: String, attributes: [String : AttributeValue], startTime: Date) -> any Span {
        let builder = tracer.spanBuilder(spanName: name)
        attributes.forEach {
            builder.setAttribute(key: $0.key, value: $0.value)
        }
        
        builder.setStartTime(time: startTime)
        
        let span = builder.startSpan()
        return span
    }
}
