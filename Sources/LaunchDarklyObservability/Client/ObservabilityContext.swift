import Combine
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
    /// Ordered stream of recorded screen views (first screen and every change),
    /// used by Session Replay to emit `Navigate` events.
    public let screenViews: AnyPublisher<ScreenViewEvent, Never>
    /// Ordered stream of `track` events from the single emitter, used by Session Replay to emit
    /// `Track` events for every track path (`LDClient.track` and the manual `LDObserve.track` API).
    public let tracks: AnyPublisher<TrackEvent, Never>
    
    public init(
        sdkKey: String,
        options: ObservabilityOptions,
        appLifecycleManager: AppLifecycleManaging,
        sessionManager: SessionManaging,
        transportService: TransportServicing,
        userInteractionManager: UserInteractionManager,
        sessionAttributes: [String: AttributeValue],
        screenViews: AnyPublisher<ScreenViewEvent, Never>,
        tracks: AnyPublisher<TrackEvent, Never>) {
            self.sdkKey = sdkKey
            self.options = options
            self.appLifecycleManager = appLifecycleManager
            self.sessionManager = sessionManager
            self.transportService = transportService
            self.userInteractionManager = userInteractionManager
            self.sessionAttributes = sessionAttributes
            self.screenViews = screenViews
            self.tracks = tracks
        }
}
