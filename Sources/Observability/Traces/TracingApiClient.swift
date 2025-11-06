import Foundation.NSDate

final class TracingApiClient: TracesApi {
    private let options: Options.TracingAPIOptions
    private let tracer: Tracer
    
    init(options: Options.TracingAPIOptions, tracer: Tracer) {
        self.options = options
        self.tracer = tracer
    }
    
    func recordError(error: any Error, attributes: [String : AttributeValue]) {
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
}

/// Internal method used to set span start date
extension TracingApiClient {
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
