import Foundation
import Combine
import LaunchDarklyObservability
import OSLog
#if !LD_COCOAPODS
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
    private var payloadId = 0
    private var title: String
    private var nextPayloadId: Int {
        payloadId += 1
        return payloadId
    }
    private var identifyPayload: IdentifyItemPayload?
    
    init(context: SessionReplayContext,
         replayApiService: SessionReplayAPIService,
         title: String) {
        self.context = context
        self.replayApiService = replayApiService
        self.sessionManager = context.observabilityContext.sessionManager
        self.title = title
        self.eventGenerator = RRWebEventGenerator(log: context.log, title: title)
        self.log = context.log
        self.sessionInfo = sessionManager.sessionInfo
        
        self.sessionCancellable = sessionManager
            .publisher()
            .sink { [weak self] newSessionInfo in
                Task { [weak self] in
                    await self?.updateSessionInfo(newSessionInfo)
                }
            }
    }
    
    private func updateSessionInfo(_ sessionInfo: SessionInfo) async {
        self.sessionInfo = sessionInfo
        self.eventGenerator = RRWebEventGenerator(log: log, title: title)
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
                identifyPayload = await IdentifyItemPayload(options: context.observabilityContext.options, sessionAttributes: context.observabilityContext.sessionAttributes, timestamp: Date().timeIntervalSince1970)
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

        var events = await eventGenerator.generateEvents(items: items)
        try await pushPayload(initializedSession: initializedSession, events: events)
        
        if shouldWakeUpSession {
            let events = await eventGenerator.generateWakeUpEvents(items: items)
            // we need a separate payload to wake up player
            try await pushPayload(initializedSession: initializedSession, events: events)
            shouldWakeUpSession = false
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
    
    deinit {
        sessionCancellable?.cancel()
    }
}
