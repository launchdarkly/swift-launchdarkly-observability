import OpenTelemetrySdk
import Common
import Foundation
import OpenTelemetryProtocolExporterCommon

final class OtlpMetricEventExporter: EventExporting {
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

    func export(items: [EventQueueItem]) async throws {
        let metricDatas: [OpenTelemetrySdk.MetricData] = items.compactMap { item in
            (item.payload as? MetricItem)?.metricData
        }
        guard metricDatas.isNotEmpty else {
            return
        }
        try await export(metricDatas: metricDatas)
    }
    
    private func export(metricDatas: [MetricData],
                        explicitTimeout: TimeInterval? = nil) async throws {
        let body =
        Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with { request in
            request.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(
                metricData: metricDatas)
        }
        
        try await otlpHttpClient.send(body: body, explicitTimeout: explicitTimeout)
    }
}
