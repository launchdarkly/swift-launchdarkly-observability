import Foundation

import OpenTelemetrySdk
import OpenTelemetryApi
import URLSessionInstrumentation

import DomainModels
import ApplicationServices


final class OTelTraceService {
    private let sessionService: SessionService
    private let options: Options
    private let exporter: SpanExporter
    private let tracer: Tracer
    private let spanProcessor: SpanProcessor
    private let uRLSessionInstrumentation: URLSessionInstrumentation
    
    init(
        sessionService: SessionService,
        options: Options,
        exporter: SpanExporter,
        urlSessionInstrumentationConfiguration: URLSessionInstrumentationConfiguration
    ) {
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
        
        let provider = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .with(resource: Resource(attributes: options.resourceAttributes.mapValues({ $0.toOTel() })))
            .build()
        
        /// Register Custom Tracer Provider
        OpenTelemetry.registerTracerProvider(
            tracerProvider: provider
        )
        
        /// Update tracer instance
        self.tracer = OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: options.serviceName,
            instrumentationVersion: options.serviceVersion
        )
        self.exporter = exporter
        self.spanProcessor = processor
        self.sessionService = sessionService
        self.options = options
        
        var configuration = urlSessionInstrumentationConfiguration
        configuration.tracer = self.tracer
        self.uRLSessionInstrumentation = URLSessionInstrumentation(
            configuration: configuration
        )
    }
    
    // MARK: - API
    
    func recordError(
        error: Error,
        attributes: [String: DomainModels.AttributeValue]
    ) {
        var attributes = attributes.mapValues { $0.toOTel() }
        let builder = tracer.spanBuilder(spanName: "highlight.error")
        
        if let parent = OpenTelemetry.instance.contextProvider.activeSpan {
            builder.setParent(parent)
        }
        
        attributes.forEach {
            builder.setAttribute(key: $0.key, value: $0.value)
        }
        let sessionId = sessionService.sessionInfo().id
        if !sessionId.isEmpty {
            builder.setAttribute(key: SemanticConvention.highlightSessionId, value: sessionId)
            attributes[SemanticConvention.highlightSessionId] = .string(sessionId)
        }
        
        
        let span = builder.startSpan()
        span.setAttributes(attributes)
        span.recordException(SpanError(error: error), attributes: attributes)
        span.end()
    }
    
    func startSpan(
        name: String,
        attributes: [String: DomainModels.AttributeValue]
    ) -> DomainModels.Span {
        let builder = tracer.spanBuilder(spanName: name)
        
        if let parent = OpenTelemetry.instance.contextProvider.activeSpan {
            builder.setParent(parent)
        }
        
        let otelAttributes = attributes.mapValues { $0.toOTel() }
        otelAttributes.forEach {
            builder.setAttribute(key: $0.key, value: $0.value)
        }
        
        let span = builder.startSpan()
        
        return .init(
            end: { time in
                span.end(time: time)
            },
            addEvent: { name, attributes, timestamp in
                span.addEvent(
                    name: name,
                    attributes: attributes.mapValues { $0.toOTel() },
                    timestamp: timestamp
                )
            }
        )
    }
    
    func flush() -> Bool {
        /// Processes all span events that have not yet been processed.
        /// This method is executed synchronously on the calling thread
        /// - Parameter timeout: Maximum time the flush complete or abort. If nil, it will wait indefinitely
        self.spanProcessor.forceFlush(timeout: 3.0)
        return true
    }
}

/*
import Foundation

import OpenTelemetrySdk
import OpenTelemetryApi
import OpenTelemetryProtocolExporterHttp

import DomainModels
import ApplicationServices
import Sampling


final class OTelTraceService {
    private let tracesPath = "/v1/traces"
    private let sessionService: SessionService
    private let options: Options
    private let otelTracer: Tracer
    private let spanProcessor: SpanProcessor
    private let sampler: ExportSampler
    
    init(sessionService: SessionService, options: Options, sampler: ExportSampler) throws {
        guard  let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(tracesPath) else {
            throw InstrumentationError.traceExporterUrlIsInvalid
        }
        
        let exporter = SamplingTraceExporterDecorator(
            exporter: OtlpHttpTraceExporter(
                endpoint: url,
                config: .init(headers: options.customHeaders)
            ),
            sampler: sampler
        )
        
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
        
        let provider = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .with(resource: Resource(attributes: options.resourceAttributes.mapValues({ $0.toOTel() })))
            .build()
        
        /// Register Custom Tracer Provider
        OpenTelemetry.registerTracerProvider(
            tracerProvider: provider
        )
        
        /// Update tracer instance
        self.otelTracer = OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: options.serviceName,
            instrumentationVersion: options.serviceVersion
        )
        
        self.spanProcessor = processor
        
        self.sessionService = sessionService
        
        self.options = options
        
        self.sampler = sampler
    }
    
    public func recordError(
        error: Error,
        attributes: [String: DomainModels.AttributeValue]
    ) {
        var attributes = attributes.mapValues { $0.toOTel() }
        let builder = otelTracer.spanBuilder(spanName: "highlight.error")
        
        if let parent = OpenTelemetry.instance.contextProvider.activeSpan {
            builder.setParent(parent)
        }
        
        attributes.forEach {
            builder.setAttribute(key: $0.key, value: $0.value)
        }
        let sessionId = sessionService.sessionInfo().id
        if !sessionId.isEmpty {
            builder.setAttribute(key: SemanticConvention.highlightSessionId, value: sessionId)
            attributes[SemanticConvention.highlightSessionId] = .string(sessionId)
        }
        
        
        let span = builder.startSpan()
        span.setAttributes(attributes)
        span.recordException(SpanError(error: error), attributes: attributes)
        span.end()
    }
    
    func startSpan(
        name: String,
        attributes: [String: DomainModels.AttributeValue]
    ) -> DomainModels.Span {
        let builder = otelTracer.spanBuilder(spanName: name)
        
        if let parent = OpenTelemetry.instance.contextProvider.activeSpan {
            builder.setParent(parent)
        }
        
        let otelAttributes = attributes.mapValues { $0.toOTel() }
        otelAttributes.forEach {
            builder.setAttribute(key: $0.key, value: $0.value)
        }
        
        return .init(
            end: { time in
                builder.startSpan().end(time: time)
            }
        )
    }
    
    func flush() -> Bool {
        /// Processes all span events that have not yet been processed.
        /// This method is executed synchronously on the calling thread
        /// - Parameter timeout: Maximum time the flush complete or abort. If nil, it will wait indefinitely
        self.spanProcessor.forceFlush(timeout: 3.0)
        return true
    }
}
*/
