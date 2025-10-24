import Foundation
import Common
import Observability
import OSLog

actor SessionReplayExporter: EventExporting {
    let replayApiService: SessionReplayAPIService
    let context: SessionReplayContext
    let sessionManager: SessionManaging
    var isInitializing = false
    var eventGenerator: SessionReplayEventGenerator
    var log: OSLog
    var initializedSession: InitializeSessionResponse?
    var sessionInfo: SessionInfo?
    private var sessionChangesTask: Task<Void, Never>?
    
    var payloadId = 0
    var nextPayloadId: Int {
        payloadId += 1
        return payloadId
    }
    
    init(context: SessionReplayContext,
         sessionManager: SessionManaging,
         replayApiService: SessionReplayAPIService) {
        self.context = context
        self.replayApiService = replayApiService
        self.sessionManager = sessionManager
        self.eventGenerator = SessionReplayEventGenerator()
        self.log = context.log
        self.sessionInfo = sessionManager.sessionInfo
        
        self.sessionChangesTask = Task(priority: .background) { [weak self, sessionManager] in
            let stream = await sessionManager.sessionChanges()
            for await newSessionInfo in stream {
                guard let self else { break }
                await self.updateSessionInfo(newSessionInfo)
                if Task.isCancelled { break }
            }
        }
    }
    
    func updateSessionInfo(_ sessionInfo: SessionInfo) async {
        self.sessionInfo = sessionInfo
        self.eventGenerator = SessionReplayEventGenerator()
        self.initializedSession = nil
    }
    
    private func initializeSessionIfNeeded() async throws {
        if initializedSession == nil {
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
                try await identifySession(session: session)
                initializedSession = session
            } catch {
                initializedSession = nil
                os_log("%{public}@", log: log, type: .error, "Failed to initialize Session Replay:\n\(error)")
            }
        }
    }
    
    func export(items: [EventQueueItem]) async throws {
        try await initializeSessionIfNeeded()
        
        guard let initializedSession else { return }
        
        let events = await eventGenerator.generateEvents(items: items)
        guard events.isNotEmpty else { return }
        
        try await pushPayload(events: events)
    }
    
    func pushPayload(events: [Event]) async throws {
        guard let initializedSession else { return }
        guard events.isNotEmpty else { return }
        
        let input = PushPayloadVariables(sessionSecureId: initializedSession.secureId, payloadId: "\(nextPayloadId)", events: events)
        try await replayApiService.pushPayload(input)
    }
    
    func initializeSession(sessionSecureId: String) async throws -> InitializeSessionResponse {
        try await replayApiService.initializeSession(context: context,
                                                     sessionSecureId: sessionSecureId,
                                                     userIdentifier: "abelonogov@launchdarkly.com")
    }
    
    func identifySession(session: InitializeSessionResponse) async throws {
        try await replayApiService.identifySession(
            sessionSecureId: session.secureId,
            userObject:   ["telemetry.sdk.name":"JSClient",
                           "telemetry.sdk.version":"3.8.1",
                           "feature_flag.set.id":"548f6741c1efad40031b18ae",
                           "feature_flag.provider.name":"LaunchDarkly",
                           "key":"test"])
    }

    deinit {
        sessionChangesTask?.cancel()
    }
}
