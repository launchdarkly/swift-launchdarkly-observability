import OpenTelemetryApi
import OpenTelemetrySdk
#if !LD_COCOAPODS
    import Common
#endif

/** Shared info between plugins */
public class ObservabilityContext {
    public let sdkKey: String
    public let options: ObservabilityOptions
    public let sessionManager: SessionManaging
    public let transportService: TransportServicing
    public let appLifecycleManager: AppLifecycleManaging
    public let userInteractionManager: UserInteractionManager
    public let sessionAttributes: [String: AttributeValue]
    
    public init(
        sdkKey: String,
        options: ObservabilityOptions,
        appLifecycleManager: AppLifecycleManaging,
        sessionManager: SessionManaging,
        transportService: TransportServicing,
        userInteractionManager: UserInteractionManager,
        sessionAttributes: [String: AttributeValue]) {
            self.sdkKey = sdkKey
            self.options = options
            self.appLifecycleManager = appLifecycleManager
            self.sessionManager = sessionManager
            self.transportService = transportService
            self.userInteractionManager = userInteractionManager
            self.sessionAttributes = sessionAttributes
        }
}
