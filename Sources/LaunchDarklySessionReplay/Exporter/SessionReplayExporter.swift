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
    /// The initialization attempt in flight, if any. Concurrent callers join it instead of carrying on
    /// without a session: the startup probe and the first export batch do overlap, and an export that
    /// returns without pushing is treated as a success, which drops its items from the queue.
    private var initializationTask: Task<Void, Error>?
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
    /// Set once the backend rejects the session unrecoverably. Recording cannot come back within this
    /// process — a new attempt is made only on a fresh launch — so no further requests are made and
    /// queued items are drained instead of retried.
    private var hasFailedUnrecoverably = false
    private var initializationHandler: (@Sendable @MainActor (SessionReplayInitializationVerdict) -> Void)?
    /// A verdict reached before the handler was attached. The handler is installed from an unordered
    /// task, so the first verdict is held here rather than dropped.
    private var pendingVerdict: SessionReplayInitializationVerdict?
    
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

    /// Receives every recording verdict. Attached after construction because the observer owns this
    /// exporter; any verdict reached in the meantime is replayed immediately.
    func setInitializationHandler(_ handler: @escaping @Sendable @MainActor (SessionReplayInitializationVerdict) -> Void) {
        initializationHandler = handler
        if let pendingVerdict {
            self.pendingVerdict = nil
            Task { @MainActor in handler(pendingVerdict) }
        }
    }

    /// Initializes the session without waiting for the first export batch, so an unrecoverable
    /// rejection can stop capture at the very start of the launch. Errors are reported through the
    /// verdict handler, so they are not rethrown here.
    func prepareSession() async {
        try? await initializeSessionIfNeeded()
    }
    
    private func initializeSessionIfNeeded() async throws {
        guard !hasFailedUnrecoverably else { return }
        guard initializedSession == nil else { return }

        if let initializationTask {
            // Await the attempt already running, so this caller ends up with the same session, or the
            // same error to retry on.
            try await initializationTask.value
            return
        }

        let task = Task { try await performInitialization() }
        initializationTask = task
        defer { initializationTask = nil }

        try await task.value
    }

    /// One initialization attempt: accepts the session with the backend, reports the recording verdict,
    /// and identifies the session.
    private func performInitialization() async throws {
        do {
            guard let sessionInfo else {
                return
            }
            
            let session = try await initializeSession(sessionSecureId: sessionInfo.id)
            // Accepting the session is the recording verdict on its own: releasing it here rather than
            // after `identifySession` keeps a transient identify failure from withholding screenshots.
            report(.allowed)

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
            reportIfUnrecoverable(error)
            throw error
        }
    }

    /// Classifies a failed request: recoverable errors are left to the export retry loop (items stay
    /// buffered until the queue overflows), while an unrecoverable one ends recording for this launch.
    private func reportIfUnrecoverable(_ error: Error) {
        guard !ErrorRecoverability.isErrorRecoverable(error) else { return }

        hasFailedUnrecoverably = true
        let reason = String(describing: error)
        os_log("%{public}@", log: log, type: .error, "Session Replay stopped, unrecoverable error:\n\(reason)")
        report(.unrecoverable(reason: reason))
    }

    private func report(_ verdict: SessionReplayInitializationVerdict) {
        guard let initializationHandler else {
            pendingVerdict = verdict
            return
        }
        Task { @MainActor in initializationHandler(verdict) }
    }
    
    func export(items: [EventQueueItem]) async throws {
        // Return without pushing so the queue drains: recording is over for this launch, and holding
        // the items would only keep the buffer full.
        guard !hasFailedUnrecoverably else { return }

        do {
            try await performExport(items: items)
        } catch {
            // The refusal that just ended recording is not a retryable export failure: rethrowing it
            // would have the worker back off (up to a minute) still holding a batch nothing accepts
            // any more, so the drain above would only start once that backoff expires.
            guard !hasFailedUnrecoverably else { return }
            throw error
        }
    }

    private func performExport(items: [EventQueueItem]) async throws {
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

        do {
            try await replayApiService.pushPayload(input)
        } catch {
            reportIfUnrecoverable(error)
            throw error
        }
        
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
        // The identify hook stays registered after recording ends, and `initializedSession` outlives the
        // refusal, so without this the abandoned session would keep receiving identify calls.
        guard !hasFailedUnrecoverably else { return }

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
