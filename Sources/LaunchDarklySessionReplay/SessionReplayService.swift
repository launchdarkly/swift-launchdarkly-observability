import Foundation
import LaunchDarklyObservability
import OSLog
import Combine
#if LD_COCOAPODS
import LaunchDarklyObservability
#else
import Common
#endif

protocol SessionReplayServicing: AnyObject {
    @MainActor
    func start(ignoreSampling: Bool) -> SessionReplayStartResult
    
    @MainActor
    func stop()
    
    @MainActor
    var isEnabled: Bool { get set }

    @MainActor
    var isRunning: Bool { get }
    
    func afterIdentify(contextKeys: [String: String], canonicalKey: String, completed: Bool)
}

struct SessionReplayContext {
    public var sdkKey: String
    public var serviceName: String
    public var backendUrl: URL
    public var log: OSLog
    public var observabilityContext: ObservabilityContext
    public var compression: SessionReplayOptions.CompressionMethod
    
    init(sdkKey: String,
         serviceName: String,
         backendUrl: URL,
         log: OSLog,
         observabilityContext: ObservabilityContext,
         compression: SessionReplayOptions.CompressionMethod) {
        self.sdkKey = sdkKey
        self.serviceName = serviceName
        self.backendUrl = backendUrl
        self.log = log
        self.observabilityContext = observabilityContext
        self.compression = compression
    }
}

final class SessionReplayService: SessionReplayServicing {
    let captureManager: CaptureManager
    var transportService: TransportServicing
    var sessionReplayExporter: SessionReplayExporter
    let userInteractionManager: UserInteractionManager
    let log: OSLog
    let sampleRate: Double
    var observabilityContext: ObservabilityContext
    
    @MainActor
    private var _isEnabled = false

    @MainActor
    private var _isRunning = false

    @MainActor
    var isEnabled: Bool {
        get {
            _isEnabled
        }
        set {
            _isEnabled = newValue
            if newValue {
                _ = start(ignoreSampling: false)
            } else {
                stop()
            }
        }
    }

    @MainActor
    var isRunning: Bool {
        _isRunning
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init(observabilityContext: ObservabilityContext,
         sessonReplayOptions: SessionReplayOptions,
         metadata: LaunchDarkly.EnvironmentMetadata) throws {
        guard let url = URL(string: observabilityContext.options.backendUrl) else {
            throw InstrumentationError.invalidGraphQLUrl
        }
        self.observabilityContext = observabilityContext
        self.log = observabilityContext.options.log
        self.sampleRate = sessonReplayOptions.sampleRate
        let graphQLClient = GraphQLClient(endpoint: url, defaultHeaders: ["User-Agent": ObservabilitySDKInfo.userAgent()])
        let captureService = ImageCaptureService(options: sessonReplayOptions)
        self.transportService = observabilityContext.transportService
        self.captureManager = CaptureManager(captureService: captureService,
                                             compression: sessonReplayOptions.compression,
                                             appLifecycleManager: observabilityContext.appLifecycleManager,
                                             eventQueue: transportService.eventQueue)
        self.userInteractionManager = observabilityContext.userInteractionManager
        
        let sessionReplayContext = SessionReplayContext(
            sdkKey: observabilityContext.sdkKey,
            serviceName: observabilityContext.options.serviceName,
            backendUrl: url,
            log: observabilityContext.options.log,
            observabilityContext: observabilityContext,
            compression: sessonReplayOptions.compression)
        
        
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
    
    func afterIdentify(contextKeys: [String: String], canonicalKey: String, completed: Bool) {
        guard completed else { return }
        Task {
            let identifyPayload = IdentifyItemPayload(
                options: observabilityContext.options,
                sessionAttributes: observabilityContext.sessionAttributes,
                contextKeys: contextKeys,
                canonicalKey: canonicalKey,
                timestamp: Date().timeIntervalSince1970
            )
            await scheduleIdentifySession(identifyPayload: identifyPayload)
        }
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
    func start(ignoreSampling: Bool = false) -> SessionReplayStartResult {
        guard !_isRunning else { return .alreadyStarted }
        guard ignoreSampling || SessionReplaySampling.shouldSample(sampleRate: sampleRate) else {
            os_log("LaunchDarkly Session Replay skipped by sampling.", log: log, type: .info)
            return .sampledOut
        }

        _isRunning = true
        _isEnabled = true
        internalStart()
        return .started
    }
    
    @MainActor
    private func internalStart() {
        userInteractionManager.interactionEvents
            .sink { [transportService] event in
                Task {
                    switch event {
                    case .touch(let interaction):
                        await transportService.eventQueue.send(interaction)
                    case .press(let pressInteraction):
                        await transportService.eventQueue.send(PressInteractionPayload(pressInteraction: pressInteraction))
                    }
                }
            }
            .store(in: &cancellables)
            
        captureManager.isEnabled = true
    }
    
    @MainActor
    func stop() {
        _isEnabled = false
        guard _isRunning else { return }
        _isRunning = false
        internalStop()
    }
    
    @MainActor
    private func internalStop() {
        cancellables.removeAll()
        captureManager.isEnabled = false
    }
}
