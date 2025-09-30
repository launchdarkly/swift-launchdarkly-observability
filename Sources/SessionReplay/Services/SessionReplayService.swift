import Foundation
import Common

public final class SessionReplayService {
    let worker: SessionReplayBackroundWorker
    let screenshotService: ScreenshotService
    let eventQueue = EventQueue()
    
    public init(graphQLClient: GraphQLClient) {
        let replayApiService = SessionReplayAPIService(gqlClient: graphQLClient)
        self.screenshotService = ScreenshotService(replayApiService: replayApiService)
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
