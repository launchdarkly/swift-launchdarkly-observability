import Foundation
import Common

struct ScreenImageItem: EventQueueItemPayload {
    func cost() -> Int {
        exportImage.data.count
    }
    
    let exportImage: ExportImage
}

protocol SessionReplayItemPayload {
    func sessionReplayEvent() -> Event?
}

public struct SessionReplayContext {

    public var sdkKey: String
    public var serviceName: String
    public var backendUrl: URL
    public var graphQLClient: GraphQLClient
    
    public init(sdkKey: String, serviceName: String, backendUrl: URL, graphQLClient: GraphQLClient) {
        self.sdkKey = sdkKey
        self.serviceName = serviceName
        self.backendUrl = backendUrl
        self.graphQLClient = graphQLClient
    }
}

public final class SessionReplayService {
    let screenshotManager: SnapshotTaker
    let serviceContainer: ServiceContainer
    let screenshotService: ReplayPushService
    public let eventQueue = EventQueue()
    let context: SessionReplayContext
    
    public init(context: SessionReplayContext,
                sessionId: String,
                observabilityExporter: ObservabilityExporter) {
        self.screenshotManager = SnapshotTaker(queue: eventQueue, captureService: ScreenCaptureService(options: SessionReplayOptions()))
        let replayPushService = ReplayPushService(context: context, sessionId: sessionId, replayApiService: SessionReplayAPIService(gqlClient: context.graphQLClient))
        let exporter = SessionReplayExporter(sessionReplayExporter: replayPushService, observabilityExporter: observabilityExporter)
        self.serviceContainer = ServiceContainer(eventSources: [screenshotManager], eventQueue: eventQueue, exporter: exporter)
        self.context = context
        let replayApiService = SessionReplayAPIService(gqlClient: context.graphQLClient)
        self.screenshotService = ReplayPushService(context: context, sessionId: sessionId, replayApiService: replayApiService)
    }
    
    public func start() {
        screenshotManager.start()
        serviceContainer.start()
    }
    
    public func stop() {
        screenshotManager.stop()
        serviceContainer.stop()
    }
    
    public func userTap(touchEvent: TouchEvent) {
        Task {
            await eventQueue.enque(EventQueueItem(payload: TouchItem(touchEvent: touchEvent)))
        }
    }
}
