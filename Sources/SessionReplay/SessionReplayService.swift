import Foundation
import Common
import Observability

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
    
    public init(sdkKey: String, serviceName: String, backendUrl: URL) {
        self.sdkKey = sdkKey
        self.serviceName = serviceName
        self.backendUrl = backendUrl
    }
}

public final class SessionReplayService {
    let screenshotManager: SnapshotTaker
    var transportService: TransportServicing
    
    public init(context: ObservabilityContext,
                sessonReplayOptions: SessionReplayOptions) throws {
        guard let url = URL(string: context.options.backendUrl) else {
            throw InstrumentationError.invalidGraphQLUrl
        }
        let graphQLClient = GraphQLClient(endpoint: url)
        
        let captureService = ScreenCaptureService(options: sessonReplayOptions)
        self.transportService = context.transportService
        self.screenshotManager = SnapshotTaker(queue: transportService.eventQueue, captureService: captureService)
        let sessionReplayContext = SessionReplayContext(
            sdkKey: context.sdkKey,
            serviceName: context.options.serviceName,
            backendUrl: url)
        
        let replayApiService = SessionReplayAPIService(gqlClient: graphQLClient)
        let replayPushService = SessionReplayExporter(context: sessionReplayContext,
                                                      sessionService: context.sessionService,
                                                      replayApiService: replayApiService)
        Task {
            await transportService.batchWorker.addExporter(replayPushService)
        }
        screenshotManager.start()
        
        // it maybe already started if observability plugin is used.
        transportService.start()
    }
}
