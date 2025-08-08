@_exported import Foundation
@preconcurrency import OpenTelemetryApi
import OpenTelemetrySdk
import StdoutExporter
import OpenTelemetryProtocolExporterHttp



public struct TracerFacade {
    private let configuration: Configuration
    public var tracer: Tracer {
        OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: configuration.serviceName,
            instrumentationVersion: configuration.serviceVersion
        )
    }
    
    public var currentSpan: Span? {
        OpenTelemetry.instance.contextProvider.activeSpan
    }
    
    public init(configuration: Configuration) {
        self.configuration = configuration
        OpenTelemetry.registerTracerProvider(
            tracerProvider: buildTracerProvider(
                using: Resource(attributes: configuration.resourceAttributes),
                spanProcessor: SimpleSpanProcessor(
                    spanExporter: buildSpanExporter(using: configuration)
                )
            )
        )
    }
    
    private func buildSpanExporter(using configuration: Configuration) -> SpanExporter {
        var spanExporters = [any SpanExporter]()
        
        if let httpExporter = buildHttpExporter(using: configuration) {
            spanExporters.append(httpExporter)
        }
        
        if configuration.isDebug {
            spanExporters.append(
                StdoutSpanExporter(isDebug: configuration.isDebug)
            )
        }
        
        return MultiSpanExporter(spanExporters: spanExporters)
    }
    
    private func buildHttpExporter(using configuration: Configuration) -> SpanExporter? {
        guard let url = URL(string: configuration.otlpEndpoint) else {
            print("Http exporter will not be available, due to invalid URL in the otlpEndpoint")
            return nil
        }
        
        let tracesUrl = url.appending(path: HttpExporterPath.traces)
        return OtlpHttpTraceExporter(
            endpoint: tracesUrl,
            envVarHeaders: configuration.customHeaders
        )
    }
    
    private func buildTracerProvider(
        using resource: Resource,
        spanProcessor: SpanProcessor
    ) -> TracerProviderSdk {
        TracerProviderBuilder()
            .add(spanProcessor: spanProcessor)
            .with(resource: resource)
            .build()
    }
    
    // MARK: - Public API
    public func spanBuilder(spanName: String) -> SpanBuilder {
        tracer
            .spanBuilder(spanName: spanName)
            
    }
}
