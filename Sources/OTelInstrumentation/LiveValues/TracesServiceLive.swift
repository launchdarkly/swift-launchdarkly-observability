import Foundation

import OpenTelemetrySdk
import InMemoryExporter
import OpenTelemetryProtocolExporterHttp
import OpenTelemetryProtocolExporterHttp

import Sampling
import ApplicationServices

extension TracesService {
    public static let noOp: Self = .init(
        recordError: { _, _ in },
        startSpan: { _,_  in .init(end: { _ in }, addEvent: { _, _, _ in }) },
        flush: { true }
    )
    
    public static func buildInMemory(
        sessionService: SessionService,
        options: Options
    ) throws -> Self {
        
        let exporter = InMemoryExporter()
        
        return build(
            sessionService: sessionService,
            options: options,
            exporter: exporter
        )
    }
    
    public static func buildHttp(
        sessionService: SessionService,
        options: Options,
        sampler: ExportSampler
    ) throws -> Self {
        guard  let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(CommonOTelPath.tracesPath) else {
            throw InstrumentationError.invalidTraceExporterUrl
        }
        
        let exporter = SamplingTraceExporterDecorator(
            exporter: OtlpHttpTraceExporter(
                endpoint: url,
                config: .init(headers: options.customHeaders.map({ ($0.key, $0.value) }))
            ),
            sampler: sampler
        )
        
        return build(
            sessionService: sessionService,
            options: options,
            exporter: exporter
        )
    }
    
    private static func build(
        sessionService: SessionService,
        options: Options,
        exporter: SpanExporter
    ) -> Self {
        guard options.traces == .enabled else {
            return .noOp
        }
        
        let service = OTelTraceService(
            sessionService: sessionService,
            options: options,
            exporter: exporter,
            urlSessionInstrumentationConfiguration: .contextPropagationConfig(options: options)
        )
        
        return .init(
            recordError: {
                service.recordError(error: $0, attributes: $1)
            },
            startSpan: {
                service.startSpan(name: $0, attributes: $1)
            },
            flush: {
                await service.flush()
            }
        )
    }
}


