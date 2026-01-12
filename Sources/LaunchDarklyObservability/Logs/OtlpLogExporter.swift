import OpenTelemetrySdk
import Foundation

#if !LD_COCOAPODS
    import OpenTelemetryProtocolExporterCommon
    import Common
#endif

public final class OtlpLogExporter: EventExporting {
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
        let logRecords: [OpenTelemetrySdk.ReadableLogRecord] = items.compactMap { item in
            (item.payload as? LogItem)?.log
        }
        guard logRecords.isNotEmpty else {
            return
        }
        try await export(logRecords: logRecords)
    }
    
    private func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord],
                        explicitTimeout: TimeInterval? = nil) async throws {
        let body =
        Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
            request.resourceLogs = LogRecordAdapter.toProtoResourceRecordLog(logRecordList: logRecords)
        }
        
        try await otlpHttpClient.send(body: body, explicitTimeout: explicitTimeout)
    }
}
