import Foundation
import Common
import Observability
import OSLog

struct ScreenImageItem: EventQueueItemPayload {
    var timestamp: TimeInterval {
        exportImage.timestamp
    }
    
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
    public var log: OSLog
    
    public init(sdkKey: String,
                serviceName: String,
                backendUrl: URL,
                log: OSLog) {
        self.sdkKey = sdkKey
        self.serviceName = serviceName
        self.backendUrl = backendUrl
        self.log = log
    }
}

public final class SessionReplayService {
    let snapshotTaker: SnapshotTaker
    var transportService: TransportServicing
    
    public init(context: ObservabilityContext,
                sessonReplayOptions: SessionReplayOptions) throws {
        guard let url = URL(string: context.options.backendUrl) else {
            throw InstrumentationError.invalidGraphQLUrl
        }
        let graphQLClient = GraphQLClient(endpoint: url)
        
        let captureService = ScreenCaptureService(options: sessonReplayOptions)
        self.transportService = context.transportService
        self.snapshotTaker = SnapshotTaker(captureService: captureService,
                                           appLifecycleManager: context.appLifecycleManager,
                                           eventQueue: transportService.eventQueue)
        snapshotTaker.start()
        
        let sessionReplayContext = SessionReplayContext(
            sdkKey: context.sdkKey,
            serviceName: context.options.serviceName,
            backendUrl: url,
            log: context.options.log)
        
        let replayApiService = SessionReplayAPIService(gqlClient: graphQLClient)
        let replayPushService = SessionReplayExporter(context: sessionReplayContext,
                                                      sessionManager: context.sessionManager,
                                                      replayApiService: replayApiService)
        Task {
            await transportService.batchWorker.addExporter(replayPushService)
        }
        
        // it maybe already started if observability plugin is used.
        transportService.start()
    }
}
