import Foundation
import OpenTelemetrySdk

final class AppLogClient: LogsApi {
    private let logLevel: Options.LogsAPIOptions
    private let logsApiClient: LogsApi
    
    init(logLevel: Options.LogsAPIOptions, logger: LogsApi) {
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
