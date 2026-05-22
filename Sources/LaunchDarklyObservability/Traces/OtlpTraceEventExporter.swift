import OpenTelemetrySdk
import Foundation
#if !LD_COCOAPODS
import JSONExporters
import Common
#endif

final class OtlpTraceEventExporter: EventExporting {
    private let otlpHttpClient: OtlpHttpClient
    
    init(endpoint: URL,
         config: OtlpConfiguration = OtlpConfiguration(),
         useSession: URLSession? = nil,
         envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
        self.otlpHttpClient = OtlpHttpClient(endpoint: endpoint,
                                             config: config,
                                             useSession: useSession,
                                             envVarHeaders: envVarHeaders)
    }
    
    func export(items: [EventQueueItem]) async throws {
        let spanDatas: [OpenTelemetrySdk.SpanData] = items.compactMap { item in
            (item.payload as? SpanItem)?.spanData
        }
        guard spanDatas.isNotEmpty else {
            return
        }
        try await export(spanDatas: spanDatas)
    }
    
    private func export(spanDatas: [OpenTelemetrySdk.SpanData],
                        explicitTimeout: TimeInterval? = nil) async throws {
        let body = JsonSpanAdapter.toJsonRequest(spanDataList: spanDatas)
        try await otlpHttpClient.send(jsonBody: body, explicitTimeout: explicitTimeout)
    }
}
