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

    func afterTrack(name: String, metricValue: Double?, attributes: [String: AttributeValue])
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
    private var samplingSession = SessionReplaySamplingSession()

    @MainActor
    var isEnabled: Bool {
        get {
            _isEnabled
        }
        set {
            guard _isEnabled != newValue else { return }
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
    /// App-lifecycle subscription, attached at init and kept for the service's lifetime (not torn
    /// down with `internalStop`) so the cold-launch foreground is never missed.
    private var lifecycleCancellable: AnyCancellable?
    /// Whether the one-shot cold-launch foreground has been forwarded to the exporter. Main-thread only.
    private var hasHandledInitialForeground = false
    /// Gates queuing of lifecycle breadcrumbs to the recording window so a sampled-out session is not
    /// initialized by a stray transition. Toggled in `internalStart`/`internalStop`. Main-thread only.
    private var lifecycleQueueingEnabled = false
    
    init(observabilityContext: ObservabilityContext,
         sessonReplayOptions: SessionReplayOptions,
         metadata: LaunchDarkly.EnvironmentMetadata,
         imageCaptureService: ImageCaptureServicing? = nil) throws {
        guard let url = URL(string: observabilityContext.options.backendUrl) else {
            throw InstrumentationError.invalidGraphQLUrl
        }
        self.observabilityContext = observabilityContext
        self.log = observabilityContext.options.log
        self.sampleRate = sessonReplayOptions.sampleRate
        let graphQLClient = GraphQLClient(endpoint: url, defaultHeaders: ["User-Agent": ObservabilitySDKInfo.userAgent()])
        let captureService = imageCaptureService
            ?? ImageCaptureService(options: sessonReplayOptions)
        self.transportService = observabilityContext.transportService
        self.captureManager = CaptureManager(captureService: captureService,
                                             compression: sessonReplayOptions.compression,
                                             frameRate: sessonReplayOptions.frameRate,
                                             appLifecycleManager: observabilityContext.appLifecycleManager,
                                             eventQueue: transportService.eventQueue,
                                             sessionIdProvider: observabilityContext.sessionManager.sessionIdProvider)
        self.userInteractionManager = observabilityContext.userInteractionManager
        
        let sessionReplayContext = SessionReplayContext(
            sdkKey: observabilityContext.sdkKey,
            serviceName: observabilityContext.options.serviceName,
            backendUrl: url,
            log: observabilityContext.options.log,
            observabilityContext: observabilityContext,
            compression: sessonReplayOptions.compression)
        
        
        let replayApiService = SessionReplayAPIService(gqlClient: graphQLClient)
        // The launch signal is resolved during Observability start (before this exporter exists), so
        // it is read once here on the main thread and injected as immutable state — never read from
        // the shared context on the exporter's background executor.
        let sessionReplayExporter = SessionReplayExporter(context: sessionReplayContext,
                                                          replayApiService: replayApiService,
                                                          title: ApplicationProperties.name ?? "iOS app",
                                                          appLaunchSignal: observabilityContext.appLaunchSignal)
        self.sessionReplayExporter = sessionReplayExporter
        
        Task {
            await transportService.batchWorker.addExporter(sessionReplayExporter)
            transportService.start()
        }

        // Subscribe synchronously here (not in `internalStart`, which is enabled via an async task and
        // would attach after the cold-launch `didBecomeActive`). The first foreground is handed to the
        // exporter via the safe `setInitialForeground` setter (emitted on the wake-up batch); later
        // transitions are queued as breadcrumbs while recording.
        lifecycleCancellable = observabilityContext.appLifecycleEvents
            .sink { [weak self] signal in
                self?.handleAppLifecycleSignal(signal)
            }
        os_log("LaunchDarkly Session Replay started, version: %{public}@", log: log, type: .info, sdkVersion)
    }

    /// Routes app-lifecycle signals (delivered on the main thread). The first foreground is the
    /// cold-launch foreground: it is stored on the exporter and emitted on the wake-up batch, so it
    /// is never queued here. Subsequent transitions are queued as `Foreground`/`Background`
    /// breadcrumbs, but only while recording so a sampled-out session isn't initialized.
    private func handleAppLifecycleSignal(_ signal: AppLifecycleSignal) {
        if signal.kind == .foreground, !hasHandledInitialForeground {
            hasHandledInitialForeground = true
            let exporter = sessionReplayExporter
            Task { await exporter.setInitialForeground(signal) }
            return
        }

        guard lifecycleQueueingEnabled else { return }
        let sessionId = observabilityContext.sessionManager.sessionInfo.id
        let payload = AppLifecycleItemPayload(signal: signal, sessionId: sessionId)
        Task { [transportService] in
            await transportService.eventQueue.send(payload)
        }
    }
    
    func afterIdentify(contextKeys: [String: String], canonicalKey: String, completed: Bool) {
        guard completed else { return }
        let sessionId = observabilityContext.sessionManager.sessionInfo.id
        Task {
            let identifyPayload = IdentifyItemPayload(
                options: observabilityContext.options,
                sessionAttributes: observabilityContext.sessionAttributes,
                contextKeys: contextKeys,
                canonicalKey: canonicalKey,
                timestamp: Date().timeIntervalSince1970,
                sessionId: sessionId
            )
            await scheduleIdentifySession(identifyPayload: identifyPayload)
        }
    }
    
    func afterTrack(name: String, metricValue: Double?, attributes: [String: AttributeValue]) {
        recordTrack(name: name, metricValue: metricValue, attributes: attributes, timestamp: Date().timeIntervalSince1970)
    }

    /// Records a `Track` timeline event onto the active recording. Shared by the cross-platform
    /// bridge (`SessionReplayHookProxy`) and the in-process track subscription fed by
    /// Observability's single emitter.
    private func recordTrack(name: String, metricValue: Double?, attributes: [String: AttributeValue], timestamp: TimeInterval) {
        let sessionId = observabilityContext.sessionManager.sessionInfo.id
        let payload = TrackItemPayload(
            name: name,
            metricValue: metricValue,
            attributes: attributes,
            timestamp: timestamp,
            sessionId: sessionId
        )
        Task { [transportService] in
            await transportService.eventQueue.send(payload)
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
        _isEnabled = true
        guard !_isRunning else { return .alreadyStarted }

        guard samplingSession.shouldStartCapture(ignoreSampling: ignoreSampling, sampleRate: sampleRate) else {
            os_log("LaunchDarkly Session Replay skipped by sampling.", log: log, type: .info)
            return .sampledOut
        }

        _isRunning = true
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

        // Mirror the web SDK's `Navigate` custom event: emit one per screen change
        // (and the first screen) while recording.
        observabilityContext.screenViews
            .sink { [transportService, observabilityContext] screenView in
                let sessionId = observabilityContext.sessionManager.sessionInfo.id
                let payload = NavigateItemPayload(
                    name: screenView.name,
                    timestamp: screenView.timestamp,
                    sessionId: sessionId
                )
                Task {
                    await transportService.eventQueue.send(payload)
                }
            }
            .store(in: &cancellables)

        // Record a `Track` event for every track path (`LDClient.track` and the manual
        // `LDObserve.track` API, including standalone init without `LDClient`), which the LD
        // client hook alone misses.
        observabilityContext.tracks
            .sink { [weak self] track in
                self?.recordTrack(
                    name: track.name,
                    metricValue: track.metricValue,
                    attributes: track.attributes,
                    timestamp: track.timestamp
                )
            }
            .store(in: &cancellables)

        // App-lifecycle breadcrumbs are handled by the lifetime subscription attached in `init`
        // (`handleAppLifecycleSignal`). Enable queueing now that recording has started; the initial
        // cold-launch foreground (forwarded to the exporter) and `Launch` are emitted on the first
        // wake-up export batch.
        lifecycleQueueingEnabled = true

        captureManager.isEnabled = true
    }
    
    @MainActor
    func stop() {
        _isEnabled = false
        samplingSession.reset()
        guard _isRunning else { return }
        _isRunning = false
        internalStop()
    }
    
    @MainActor
    private func internalStop() {
        cancellables.removeAll()
        lifecycleQueueingEnabled = false
        captureManager.isEnabled = false
    }
}
