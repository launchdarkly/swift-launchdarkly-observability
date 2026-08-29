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
    public let sessionAttributes: [String: AttributeValue]
    /// Ordered stream of recorded screen views (first screen and every change),
    /// used by Session Replay to emit `Navigate` events.
    public let screenViews: AnyPublisher<ScreenViewEvent, Never>
    /// Ordered stream of `track` events from the single emitter, used by Session Replay to emit
    /// `Track` events for every track path (`LDClient.track` and the manual `LDObserve.track` API).
    public let tracks: AnyPublisher<TrackEvent, Never>
    /// Ordered stream of identified contexts from the single identify funnel, used by Session Replay
    /// to identify the session for every path (`LDClient.identify` and the manual
    /// `LDObserve.identify` API).
    public let identifies: AnyPublisher<IdentifyEvent, Never>
    /// Ordered stream of app-lifecycle signals, used by Session Replay to emit
    /// `Open` / `Foreground` / `Background` breadcrumbs.
    public let appLifecycleEvents: AnyPublisher<AppLifecycleSignal, Never>

    /// The touch-capture pipeline, present only when an instrumentation package supplied one.
    /// `nil` when the SDK runs as a plain OTel pipeline, in which case Session Replay records
    /// no interactions.
    public private(set) var userInteractionManager: UserInteractionManaging?
    /// The process-launch signal, present only when an instrumentation package resolved one.
    /// A one-shot setup value (immutable once attached): Session Replay reads it at construction
    /// and injects it into the exporter, so the `Launch` breadcrumb is delivered without a
    /// cross-thread read of this shared context.
    public private(set) var appLaunchSignal: AppLaunchSignal?

    public init(
        sdkKey: String,
        options: ObservabilityOptions,
        appLifecycleManager: AppLifecycleManaging,
        sessionManager: SessionManaging,
        transportService: TransportServicing,
        sessionAttributes: [String: AttributeValue],
        screenViews: AnyPublisher<ScreenViewEvent, Never>,
        tracks: AnyPublisher<TrackEvent, Never>,
        identifies: AnyPublisher<IdentifyEvent, Never>,
        appLifecycleEvents: AnyPublisher<AppLifecycleSignal, Never>) {
            self.sdkKey = sdkKey
            self.options = options
            self.appLifecycleManager = appLifecycleManager
            self.sessionManager = sessionManager
            self.transportService = transportService
            self.sessionAttributes = sessionAttributes
            self.screenViews = screenViews
            self.tracks = tracks
            self.identifies = identifies
            self.appLifecycleEvents = appLifecycleEvents
        }

    /// Publishes the instrumentation-supplied setup values. Called once, while the
    /// Observability plugin registers, so both are settled before any other plugin
    /// (notably Session Replay) reads this context.
    func attach(userInteractionManager: UserInteractionManaging?, appLaunchSignal: AppLaunchSignal?) {
        self.userInteractionManager = userInteractionManager
        self.appLaunchSignal = appLaunchSignal
    }
}
