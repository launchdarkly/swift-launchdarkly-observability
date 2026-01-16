import Foundation
import LaunchDarklyObservability
import OSLog
import Combine
#if !LD_COCOAPODS
import Common
#endif

protocol SessionReplayServicing {
    @MainActor
    func start(
        
    )
    @MainActor
    func stop()
}

struct SessionReplayContext {
    public var sdkKey: String
    public var serviceName: String
    public var backendUrl: URL
    public var log: OSLog
    public var observabilityContext: ObservabilityContext
    
    init(sdkKey: String,
         serviceName: String,
         backendUrl: URL,
         log: OSLog,
         observabilityContext: ObservabilityContext) {
        self.sdkKey = sdkKey
        self.serviceName = serviceName
        self.backendUrl = backendUrl
        self.log = log
        self.observabilityContext = observabilityContext
    }
}

final class SessionReplayService: SessionReplayServicing {
    let snapshotTaker: SnapshotTaker
    var transportService: TransportServicing
    var sessionReplayExporter: SessionReplayExporter
    let userInteractionManager: UserInteractionManager
    let log: OSLog
    var isRunning: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    init(observabilityContext: ObservabilityContext,
         sessonReplayOptions: SessionReplayOptions,
         metadata: LaunchDarkly.EnvironmentMetadata) throws {
        guard let url = URL(string: observabilityContext.options.backendUrl) else {
            throw InstrumentationError.invalidGraphQLUrl
        }
        
        self.log = observabilityContext.options.log
        let graphQLClient = GraphQLClient(endpoint: url)
        let captureService = ScreenCaptureService(options: sessonReplayOptions)
        self.transportService = observabilityContext.transportService
        self.snapshotTaker = SnapshotTaker(captureService: captureService,
                                           appLifecycleManager: observabilityContext.appLifecycleManager,
                                           eventQueue: transportService.eventQueue)
        self.userInteractionManager = observabilityContext.userInteractionManager
        
        let sessionReplayContext = SessionReplayContext(
            sdkKey: observabilityContext.sdkKey,
            serviceName: observabilityContext.options.serviceName,
            backendUrl: url,
            log: observabilityContext.options.log,
            observabilityContext: observabilityContext)
        
        
        let replayApiService = SessionReplayAPIService(gqlClient: graphQLClient)
        let sessionReplayExporter = SessionReplayExporter(context: sessionReplayContext,
                                                          replayApiService: replayApiService,
                                                          title: ApplicationProperties.name ?? "iOS app")
        self.sessionReplayExporter = sessionReplayExporter
        
        Task {
            await transportService.batchWorker.addExporter(sessionReplayExporter)
            transportService.start()
        }
        os_log("LaunchDarkly Session Replay started, version: %{public}@", log: log, type: .info, sdkVersion)
    }
    
    func scheduleIdentifySession(identifyPayload: IdentifyItemPayload) async {
        do {
            try await sessionReplayExporter.identifySession(identifyPayload: identifyPayload)
            await transportService.eventQueue.send(identifyPayload)
        } catch {
            os_log("%{public}@", log: log, type: .error, "Failed to identifySession:\n\(error)")
        }
    }
    
    @MainActor
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        userInteractionManager.publisher
            .sink { [transportService] interaction in
                Task {
                    await transportService.eventQueue.send(interaction)
                }
            }
            .store(in: &cancellables)
            
        snapshotTaker.start()
    }
    
    @MainActor
    func stop() {
        guard isRunning else { return }
        isRunning = false
        
        cancellables.removeAll()
        snapshotTaker.stop()
    }
}
