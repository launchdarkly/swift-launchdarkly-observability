import OpenTelemetryApi
import OpenTelemetrySdk

import API
import Common

public struct ObservabilityContext {
    public let sdkKey: String
    public let resource: Resource
    public let options: Options
    public let logger: ObservabilityLogger
    
    public init(
        sdkKey: String,
        resource: Resource,
        options: Options,
        logger: ObservabilityLogger = .init()
    ) {
        self.sdkKey = sdkKey
        self.resource = resource
        self.options = options
        self.logger = logger
    }
}
