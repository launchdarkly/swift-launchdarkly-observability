import OpenTelemetrySdk
import Common
import Foundation
//import OpenTelemetryProtocolExporterCommon

public final class ObservabilityExporter: EventExporting {
    let networkClient: NetworkClient
    let logRecordExporter: LogRecordExporter
    
    public init(logRecordExporter: LogRecordExporter, networkClient: NetworkClient) {
        self.logRecordExporter = logRecordExporter
        self.networkClient = networkClient
    }
    
    public func export(items: [EventQueueItem]) async throws {
        
    }
    
    public func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord],
                       explicitTimeout: TimeInterval? = nil) async throws {
//
//      let body =
//        Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
//          request.resourceLogs = LogRecordAdapter.toProtoResourceRecordLog(logRecordList: logRecords)
//        }
//
//      var request = createRequest(body: body, endpoint: endpoint)
//      if let headers = envVarHeaders {
//        headers.forEach { key, value in
//          request.addValue(value, forHTTPHeaderField: key)
//        }
//
//      } else if let headers = config.headers {
//        headers.forEach { key, value in
//          request.addValue(value, forHTTPHeaderField: key)
//        }
//      }
//      exporterMetrics?.addSeen(value: sendingLogRecords.count)
//      request.timeoutInterval = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, config.timeout)
//      networkClient.send(request: request) { [weak self] result in
//        switch result {
//        case .success:
//          self?.exporterMetrics?.addSuccess(value: sendingLogRecords.count)
//        case let .failure(error):
//          self?.exporterMetrics?.addFailed(value: sendingLogRecords.count)
//          self?.exporterLock.withLockVoid {
//            self?.pendingLogRecords.append(contentsOf: sendingLogRecords)
//          }
//          print(error)
//        }
//      }
//
//      return .success
    }
}
