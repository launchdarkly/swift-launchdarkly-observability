import Foundation
import OpenTelemetrySdk

final class AppLogClient: LogsApi {
    private let options: Options.LogsAPIOptions
    private let logsApiClient: LogsApi
    
    init(options: Options.LogsAPIOptions, logger: LogsApi) {
        self.options = options
        self.logsApiClient = logger
    }
    
    func recordLog(
        message: String,
        severity: OpenTelemetryApi.Severity,
        attributes: [String : OpenTelemetryApi.AttributeValue]
    ) {
        /// Options.LogsAPIOptions is bijective with OpenTelemetryApi.Severity
        guard severity.rawValue >= options.rawValue else {
            return
        }
        
        logsApiClient.recordLog(message: message, severity: severity, attributes: attributes)
    }
}
