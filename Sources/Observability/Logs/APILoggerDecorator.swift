import Foundation
import OpenTelemetrySdk

final class APILoggerDecorator: LogsApi {
    private let options: Options.LogsAPIOptions
    private let logger: LogsApi
    
    init(options: Options.LogsAPIOptions, logger: LogsApi) {
        self.options = options
        self.logger = logger
    }
    
    func recordLog(
        message: String,
        severity: OpenTelemetryApi.Severity,
        attributes: [String : OpenTelemetryApi.AttributeValue]
    ) {
        /// Options.LogsAPIOptions is bijective with OpenTelemetryApi.Severity
        guard options.rawValue == severity.rawValue else {
            return
        }
        
        logger.recordLog(message: message, severity: severity, attributes: attributes)
    }
}
