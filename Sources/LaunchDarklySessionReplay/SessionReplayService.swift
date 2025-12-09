import Foundation
import LaunchDarklyObservability
import OSLog
#if !LD_COCOAPODS
import Common
#endif

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
    var sessionReplayExporter: SessionReplayExporter
    let log: OSLog
    
    public init(context: ObservabilityContext,
                sessonReplayOptions: SessionReplayOptions) throws {
        self.log = context.options.log
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
        
        let eventQueue = transportService.eventQueue
        let userInteractionManager = context.userInteractionManager
        userInteractionManager.addYield { interaction in
            Task {
                await eventQueue.send(interaction)
            }
        }
        
        let sessionReplayContext = SessionReplayContext(
            sdkKey: context.sdkKey,
            serviceName: context.options.serviceName,
            backendUrl: url,
            log: context.options.log)
        
        let replayApiService = SessionReplayAPIService(gqlClient: graphQLClient)
        let sessionReplayExporter = SessionReplayExporter(context: sessionReplayContext,
                                                          sessionManager: context.sessionManager,
                                                          replayApiService: replayApiService)
        self.sessionReplayExporter = sessionReplayExporter
        Task {
            await transportService.batchWorker.addExporter(sessionReplayExporter)
            transportService.start()
        }
    }
    
    func scheduleIdentifySession(userObject: [String: String]) async {
        let payload = IdentifyItemPayload(attributes: userObject, timestamp: Date().timeIntervalSince1970)
        do {
            try await sessionReplayExporter.identifySession(userObject: userObject)
            await transportService.eventQueue.send(payload)
        } catch {
            os_log("%{public}@", log: log, type: .error, "Failed to identifySession:\n\(error)")
        }
    }
}
