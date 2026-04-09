import Foundation
import OpenTelemetrySdk

final class AppLogClient: LogsApi {
    private let logLevel: ObservabilityOptions.LogLevel
    private let logsApiClient: InternalLogsApi
    
    init(logLevel: ObservabilityOptions.LogLevel, logger: InternalLogsApi) {
        self.logLevel = logLevel
        self.logsApiClient = logger
    }
    
    func recordLog(
        message: String,
        severity: OpenTelemetryApi.Severity,
        attributes: [String : OpenTelemetryApi.AttributeValue],
        spanContext: SpanContext?
    ) {
        guard severity.rawValue >= logLevel.rawValue else {
            return
        }
        
        logsApiClient.recordLog(message: message, severity: severity, attributes: attributes, spanContext: spanContext)
    }
}
