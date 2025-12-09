import Foundation
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
    private var eventGenerator: SessionReplayEventGenerator
    private var log: OSLog
    private var initializedSession: InitializeSessionResponse?
    private var sessionInfo: SessionInfo?
    private var sessionChangesTask: Task<Void, Never>?
    private var shouldWakeUpSession = true
    
    private var payloadId = 0
    private var nextPayloadId: Int {
        payloadId += 1
        return payloadId
    }
    
    private var userObject: [String: String]?
    
    init(context: SessionReplayContext,
         sessionManager: SessionManaging,
         replayApiService: SessionReplayAPIService) {
        self.context = context
        self.replayApiService = replayApiService
        self.sessionManager = sessionManager
        self.eventGenerator = SessionReplayEventGenerator(log: context.log)
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
    
    private func updateSessionInfo(_ sessionInfo: SessionInfo) async {
        self.sessionInfo = sessionInfo
        self.eventGenerator = SessionReplayEventGenerator(log: log)
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
            initializedSession = session
        } catch {
            initializedSession = nil
            os_log("%{public}@", log: log, type: .error, "Failed to initialize Session Replay:\n\(error)")
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
    }
    
    private func initializeSession(sessionSecureId: String) async throws -> InitializeSessionResponse {
        try await replayApiService.initializeSession(context: context,
                                                     sessionSecureId: sessionSecureId,
                                                     userIdentifier: "")
    }
    
    private func identifySession(sessionSecureId: String) async throws {
        try await replayApiService.identifySession(
            sessionSecureId: sessionSecureId,
            userObject: userObject)
    }

    func identifySession(userObject: [String: String]) async throws {
        guard let initializedSession else { return }

        try await identifySession(userObject: userObject)
        self.userObject = userObject
    }
    
    deinit {
        sessionChangesTask?.cancel()
    }
}
