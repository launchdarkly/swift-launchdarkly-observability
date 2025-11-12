import Foundation
import OpenTelemetrySdk

final class AppLogClient: LogsApi {
    private let logLevel: Options.LogLevel
    private let logsApiClient: LogsApi
    
    init(logLevel: Options.LogLevel, logger: LogsApi) {
        self.logLevel = logLevel
        self.logsApiClient = logger
    }
    
    func recordLog(
        message: String,
        severity: OpenTelemetryApi.Severity,
        attributes: [String : OpenTelemetryApi.AttributeValue]
    ) {
        /// Options.LogsAPIOptions is bijective with OpenTelemetryApi.Severity
        guard severity.rawValue >= logLevel.rawValue else {
            return
        }
        
        logsApiClient.recordLog(message: message, severity: severity, attributes: attributes)
    }
}
