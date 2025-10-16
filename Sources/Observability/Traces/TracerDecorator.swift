import Foundation
import OpenTelemetrySdk

final class TracerDecorator: Tracer {
    private let options: Options
    private let sessionManager: SessionManaging
    private let tracerProvider: any TracerProvider
    private let spanProcessor: any SpanProcessor
    private let tracer: any Tracer

    init(options: Options, sessionManager: SessionManaging, exporter: SpanExporter) {
        self.options = options
        self.sessionManager = sessionManager
        /// Using the default values from OpenTelemetry for Swift
        /// For reference check:
        ///https://github.com/open-telemetry/opentelemetry-swift/blob/main/Sources/OpenTelemetrySdk/Trace/SpanProcessors/BatchSpanProcessor.swift
        let processor = BatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: 5,
            exportTimeout: 30,
            maxQueueSize: 2048,
            maxExportBatchSize: 512,
        )
        self.spanProcessor = processor
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
        tracer.spanBuilder(spanName: spanName)
    }
}

extension TracerDecorator: TracesApi {
    func recordError(error: any Error, attributes: [String : AttributeValue]) {
        let builder = tracer.spanBuilder(spanName: "highlight.error")
        
        if let parent = OpenTelemetry.instance.contextProvider.activeSpan {
            builder.setParent(parent)
        }
        
        attributes.forEach {
            builder.setAttribute(key: $0.key, value: $0.value)
        }
        let sessionId = sessionManager.sessionInfo.id
        var attributes = attributes
        if !sessionId.isEmpty {
            builder.setAttribute(key: SemanticConvention.highlightSessionId, value: sessionId)
            attributes[SemanticConvention.highlightSessionId] = .string(sessionId)
        }
        
        
        let span = builder.startSpan()
        span.setAttributes(attributes)
        span.recordException(SpanError(error: error), attributes: attributes)
        span.end()
    }
    
    func startSpan(name: String, attributes: [String : AttributeValue]) -> any Span {
        let builder = tracer.spanBuilder(spanName: name)
        
        if let parent = OpenTelemetry.instance.contextProvider.activeSpan {
            builder.setParent(parent)
        }
        
        attributes.forEach {
            builder.setAttribute(key: $0.key, value: $0.value)
        }
        
        let span = builder.startSpan()
        
        return span
    }
    
    func flush() -> Bool {
        /// span processor flush method differs from metrics and logs, it doesn't return a Result type
        /// Processes all span events that have not yet been processed.
        /// This method is executed synchronously on the calling thread
        /// - Parameter timeout: Maximum time the flush complete or abort. If nil, it will wait indefinitely
        /// func forceFlush(timeout: TimeInterval?)
        spanProcessor.forceFlush(timeout: 5.0)
        return true
    }
}
