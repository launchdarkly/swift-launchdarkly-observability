import Foundation
import Combine
import LaunchDarklyObservability
import OSLog
#if LD_COCOAPODS
    import LaunchDarklyObservability
#else
    import Common
#endif

actor SessionReplayExporter: EventExporting {
    private let replayApiService: SessionReplayAPIService
    private let context: SessionReplayContext
    private let sessionManager: SessionManaging
    private var isInitializing = false
    private var eventGenerator: RRWebEventGenerator
    private var log: OSLog
    private var initializedSession: InitializeSessionResponse?
    private var sessionInfo: SessionInfo?
    private var sessionCancellable: AnyCancellable?
    private var shouldWakeUpSession = true
    /// The process-launch signal, injected at construction (resolved before the exporter exists).
    /// Owned by the exporter (actor-isolated) rather than read from `ObservabilityContext` so the
    /// `Launch` breadcrumb delivery is free of cross-thread access.
    private let appLaunchSignal: AppLaunchSignal?
    /// The cold-launch `Foreground` breadcrumb, delivered via `setInitialForeground(_:)` because it
    /// can fire after construction. Owned (actor-isolated) instead of read from `ObservabilityContext`.
    private var initialForegroundSignal: AppLifecycleSignal?
    /// The initial foreground can be delivered *after* the one-time wake-up payload has already been
    /// sent (late `didBecomeActive`), so it is consumed exactly once here, independent of
    /// `shouldWakeUpSession`.
    private var hasEmittedInitialForeground = false
    private var payloadId = 0
    private var title: String
    private var nextPayloadId: Int {
        payloadId += 1
        return payloadId
    }
    private var identifyPayload: IdentifyItemPayload?
    
    init(context: SessionReplayContext,
         replayApiService: SessionReplayAPIService,
         title: String,
         appLaunchSignal: AppLaunchSignal?) {
        self.context = context
        self.replayApiService = replayApiService
        self.sessionManager = context.observabilityContext.sessionManager
        self.title = title
        self.appLaunchSignal = appLaunchSignal
        self.eventGenerator = RRWebEventGenerator(log: context.log, title: title, method: context.compression)
        self.log = context.log
        self.sessionInfo = sessionManager.sessionInfo
        
        Task { await self.subscribeToSession() }
    }
    
    private func subscribeToSession() {
        self.sessionCancellable = sessionManager
            .publisher()
            .sink { [weak self] newSessionInfo in
                Task { [weak self] in
                    await self?.updateSessionInfo(newSessionInfo)
                }
            }
        
        // Reconcile once after subscribing to avoid missing a session update
        // emitted between init-time snapshot and sink attachment.
        let latestSessionInfo = sessionManager.sessionInfo
        if latestSessionInfo != sessionInfo {
            updateSessionInfo(latestSessionInfo)
        }
    }
    
    private func updateSessionInfo(_ sessionInfo: SessionInfo) {
        self.sessionInfo = sessionInfo
        self.eventGenerator = RRWebEventGenerator(log: log, title: title, method: context.compression)
        self.initializedSession = nil
    }
    
    private func initializeSessionIfNeeded() async throws {
        guard initializedSession == nil else { return }
      
        guard !isInitializing else { return }
        isInitializing = true
        defer {
            isInitializing = false
        }
        
        do {
            guard let sessionInfo else {
                return
            }
            
            let session = try await initializeSession(sessionSecureId: sessionInfo.id)
            var identifyPayload = self.identifyPayload
            if identifyPayload == nil {
                identifyPayload = await IdentifyItemPayload(options: context.observabilityContext.options, sessionAttributes: context.observabilityContext.sessionAttributes, timestamp: Date().timeIntervalSince1970, sessionId: sessionInfo.id)
            }
            if let identifyPayload {
                try await identifySession(sessionSecureId: session.secureId, userObject: identifyPayload.attributes)
            }
            initializedSession = session
        } catch {
            initializedSession = nil
            os_log("%{public}@", log: log, type: .error, "Failed to initialize Session Replay:\n\(error)")
            throw error
        }
    }
    
    func export(items: [EventQueueItem]) async throws {
        try await initializeSessionIfNeeded()
        guard let initializedSession else { return }

        let events = await eventGenerator.generateEvents(items: items)
        try await pushPayload(initializedSession: initializedSession, events: events)
        
        if shouldWakeUpSession {
            let cachedForeground = initialForegroundSignal
            let events = await eventGenerator.generateWakeUpEvents(
                items: items,
                appLaunchSignal: appLaunchSignal,
                appLifecycleSignal: cachedForeground
            )
            // The wake-up payload (Reload + cached `Launch` breadcrumb + player wake-up) is empty
            // until a snapshot sets the image node id. Only clear the flag once we actually have
            // events to send; otherwise a first batch without a snapshot would drop these
            // breadcrumbs permanently.
            if events.isNotEmpty {
                // we need a separate payload to wake up player
                try await pushPayload(initializedSession: initializedSession, events: events)
                shouldWakeUpSession = false
                // The wake-up batch carries the cached foreground only when it was already
                // available at this point; mark it emitted so the late path below can't duplicate it.
                if cachedForeground != nil {
                    hasEmittedInitialForeground = true
                }
            }
        } else if !hasEmittedInitialForeground,
                  let cachedForeground = initialForegroundSignal {
            // The cold-launch foreground can be handled after the one-time wake-up payload has
            // already been sent (late `didBecomeActive`). Its breadcrumb is owned here but never
            // re-read by the wake-up path, so emit it here on the next export with a snapshot so
            // it isn't dropped.
            let events = await eventGenerator.generateInitialForegroundEvents(appLifecycleSignal: cachedForeground)
            if events.isNotEmpty {
                try await pushPayload(initializedSession: initializedSession, events: events)
                hasEmittedInitialForeground = true
            }
        }
    }
    
    private func pushPayload(initializedSession: InitializeSessionResponse, events: [Event]) async throws {
        guard events.isNotEmpty else { return }
        
        let input = PushPayloadVariables(sessionSecureId: initializedSession.secureId, payloadId: "\(nextPayloadId)", events: events)
                
        try await replayApiService.pushPayload(input)
        
        // flushes generating canvas size into pushedCanvasSize
        await eventGenerator.updatePushedCanvasSize()
    }
    
    private func initializeSession(sessionSecureId: String) async throws -> InitializeSessionResponse {
        try await replayApiService.initializeSession(context: context,
                                                     sessionSecureId: sessionSecureId,
                                                     userIdentifier: "")
    }
    
    private func identifySession(sessionSecureId: String, userObject: [String: String]) async throws {
        try await replayApiService.identifySession(
            sessionSecureId: sessionSecureId,
            userIdentifier: userObject["key"] ?? "unknown",
            userObject: userObject)
    }

    func identifySession(identifyPayload: IdentifyItemPayload) async throws {
        self.identifyPayload = identifyPayload

        guard let initializedSession else { return }
        
        try await identifySession(
            sessionSecureId: initializedSession.secureId,
            userObject: identifyPayload.attributes)
    }

    /// Safely assigns the cold-launch `Foreground` signal into actor-isolated state (mirroring
    /// `identifySession(identifyPayload:)`). Called from the live app-lifecycle subscription for the
    /// first foreground; the breadcrumb is emitted on the next export with a snapshot. Only the first
    /// foreground is retained so a later background/foreground cycle can't overwrite it.
    func setInitialForeground(_ signal: AppLifecycleSignal) {
        guard initialForegroundSignal == nil, !hasEmittedInitialForeground else { return }
        initialForegroundSignal = signal
    }
    
    deinit {
        sessionCancellable?.cancel()
    }
}
