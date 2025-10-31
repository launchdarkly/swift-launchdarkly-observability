import OpenTelemetryApi
import OpenTelemetrySdk
import Common

/** Shared info between plugins */
public class ObservabilityContext {
    public let sdkKey: String
    public let options: Options
    public let sessionManager: SessionManaging
    public let transportService: TransportServicing
    public let appLifecycleManager: AppLifecycleManaging
    public let userInteractionManager: UserInteractionManager
    
    public init(
        sdkKey: String,
        options: Options,
        appLifecycleManager: AppLifecycleManaging,
        sessionManager: SessionManaging,
        transportService: TransportServicing,
        userInteractionManager: UserInteractionManager) {
            self.sdkKey = sdkKey
            self.options = options
            self.appLifecycleManager = appLifecycleManager
            self.sessionManager = sessionManager
            self.transportService = transportService
            self.userInteractionManager = userInteractionManager
        }
}
