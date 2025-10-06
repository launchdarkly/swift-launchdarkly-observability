import Foundation

import OpenTelemetrySdk
import OpenTelemetryProtocolExporterHttp

import ApplicationServices

extension MetricsService {
    public static let noOp: Self = MetricsService(
        recordMetric: { _ in },
        recordCount: { _ in },
        recordIncr: { _ in },
        recordHistogram: { _ in },
        recordUpDownCounter: { _ in },
        flush: { true }
    )
    
    public static func buildHttp(
        sessionService: SessionService,
        options: Options
    ) throws -> Self {
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(CommonOTelPath.metricsPath) else {
            throw InstrumentationError.invalidMetricExporterUrl
        }
        
        let exporter = OtlpHttpMetricExporter(
            endpoint: url,
            config: .init(headers: options.customHeaders)
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
        exporter: MetricExporter
    ) -> Self {
        guard options.metrics == .enabled else {
            return .noOp
        }
        
        let service = OTelMetricsService(
            sessionService: sessionService,
            options: options,
            exporter: exporter
        )
        
        return .init(
            recordMetric: { service.recordMetric(metric: $0) },
            recordCount: { service.recordCount(metric: $0) },
            recordIncr: { service.recordIncr(metric: $0) },
            recordHistogram: { service.recordHistogram(metric: $0) },
            recordUpDownCounter: { service.recordUpDownCounter(metric: $0) },
            flush: { await service.flush() }
        )
    }
}


