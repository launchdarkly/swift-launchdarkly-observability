import OpenTelemetrySdk
import Common
import Foundation
import OpenTelemetryProtocolExporterCommon

public final class OtlpMetricEventExporter: EventExporting {
    let otlpHttpClient: OtlpHttpClient
    
    public init(endpoint: URL,
                config: OtlpConfiguration = OtlpConfiguration(),
                useSession: URLSession? = nil,
                envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
        self.otlpHttpClient = OtlpHttpClient(endpoint: endpoint,
                                             config: config,
                                             useSession: useSession,
                                             envVarHeaders: envVarHeaders)
    }

    public func export(items: [EventQueueItem]) async throws {
//        let logRecords: [OpenTelemetrySdk.MetricData] = items.compactMap { item in
//            (item.payload as? Metric)?.log
//        }
//        guard logRecords.isNotEmpty else {
//            return
//        }
//        try await export(logRecords: logRecords)
    }
    
    private func export(metrics: [MetricData],
                        explicitTimeout: TimeInterval? = nil) async throws {
        let body =
        Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with { request in
            request.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(
                metricData: metrics)
        }
        
        try await otlpHttpClient.send(body: body, explicitTimeout: explicitTimeout)
    }
}
