import Foundation
import OpenTelemetrySdk

final class TracerDecorator: Tracer {
    private let options: Options
    private let sessionManager: SessionManaging
    private let tracerProvider: any TracerProvider
    private let tracer: any Tracer
    private var activeSpan: Span?
    
    init(options: Options, sessionManager: SessionManaging, sampler: ExportSampler, eventQueue: EventQueue) {
        self.options = options
        self.sessionManager = sessionManager
        let processor = EventSpanProcessor(eventQueue: eventQueue, sampler: sampler)
        let provider = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .with(resource: Resource(attributes: options.resourceAttributes))
            .build()
        self.tracerProvider = provider
        self.tracer = tracerProvider.get(
            instrumentationName: options.serviceName,
            instrumentationVersion: options.serviceVersion,
            schemaUrl: nil,
            attributes: options.resourceAttributes
        )
    }
    
    func spanBuilder(spanName: String) -> any SpanBuilder {
        let builder = tracer.spanBuilder(spanName: spanName)

        if let parent = OpenTelemetry.instance.contextProvider.activeSpan {
            builder.setParent(parent)
        }
        
        let sessionId = sessionManager.sessionInfo.id
        if !sessionId.isEmpty {
            builder.setAttribute(key: SemanticConvention.sessionId, value: sessionId)
        }
        
        return builder
    }
}

extension TracerDecorator: TracesApi {
    func recordError(error: any Error, attributes: [String : AttributeValue]) {
        let builder = spanBuilder(spanName: "highlight.error")
    
        attributes.forEach {
            builder.setAttribute(key: $0.key, value: $0.value)
        }

        let span = builder.startSpan()
        span.setAttributes(attributes)
        span.recordException(SpanError(error: error), attributes: attributes)
        span.end()
    }
    
    func startSpan(name: String, attributes: [String : AttributeValue]) -> any Span {
        let builder = spanBuilder(spanName: name)
        attributes.forEach {
            builder.setAttribute(key: $0.key, value: $0.value)
        }
        
        let span = builder.startSpan()
        return span
    }
}

/// Internal method used to set span start date
extension Tracer {
    func startSpan(name: String, attributes: [String : AttributeValue], startTime: Date) -> any Span {
        let builder = spanBuilder(spanName: name)
        attributes.forEach {
            builder.setAttribute(key: $0.key, value: $0.value)
        }
        
        builder.setStartTime(time: startTime)
        
        let span = builder.startSpan()
        return span
    }
}
