import Foundation
import Common

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
    let worker: SessionReplayBackroundWorker
    let screenshotService: ReplayPushService
    let eventQueue = EventQueue()
    let context: SessionReplayContext
    
    public init(context: SessionReplayContext,
                sessionId: String) {
        self.context = context
        let replayApiService = SessionReplayAPIService(gqlClient: context.graphQLClient)
        self.screenshotService = ReplayPushService(context: context, sessionId: sessionId, replayApiService: replayApiService)
        self.worker = SessionReplayBackroundWorker(options: SessionReplayOptions(),
                                                   screenshotService: screenshotService,
                                                   eventQueue: eventQueue)
    }
    
    public func start() {
        worker.start()
    }
    
    public func stop() {
        worker.stop()
    }
    
    public func userTap(touchEvent: TouchEvent) {
        Task {
            await eventQueue.enque(EventQueueItem(payload: .tap(touch: touchEvent)))
        }
    }
}
