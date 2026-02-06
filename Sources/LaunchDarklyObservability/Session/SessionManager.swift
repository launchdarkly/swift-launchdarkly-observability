import Foundation
import Combine
import UIKit.UIApplication
import OSLog
#if !LD_COCOAPODS
    import Common
#endif

public protocol SessionManaging {
    func startNewSession() async throws
    func publisher() -> AnyPublisher<SessionInfo, Never>
    var sessionInfo: SessionInfo { get }
}

/// Holds a Combine subject so it can be captured in @Sendable closures.
/// Sending is constrained to a single serial queue (notificationQueue), so this is safe.
private final class SessionSubjectHolder: @unchecked Sendable {
    let subject = PassthroughSubject<SessionInfo, Never>()
}

final class SessionManager: SessionManaging {
    private let appLifecycleManager: AppLifecycleManaging
    private let options: SessionOptions
    private let sessionManagerInfoProvider: SessionManagerInfoProvider
    private let subjectHolder = SessionSubjectHolder()
    private var subject: PassthroughSubject<SessionInfo, Never> { subjectHolder.subject }
    private var _sessionInfo = SessionInfo()
    private var backgroundTime: DispatchTime?
    private var cancellables = Set<AnyCancellable>()
    private let notificationQueue = DispatchQueue(label: "com.launchdarkly.observability.session-notifications")
        
    private let stateQueue = DispatchQueue(
        label: "com.launchdarkly.observability.state-queue",
        attributes: .concurrent)
    
    init(options: SessionOptions, appLifecycleManager: AppLifecycleManaging, sessionIdProvider: SessionIdProvider? = nil) {
        self.options = options
        self.appLifecycleManager = appLifecycleManager
        if let sessionIdProvider {
            self.sessionManagerInfoProvider = LaunchDarklySessionInfoProvider(sessionIdProvider: sessionIdProvider)
        } else {
            self.sessionManagerInfoProvider = LaunchDarklySessionInfoProvider()
        }
        self._sessionInfo = SessionInfo()
        
        Task { [weak self] in
            // nil means, no custom id provider
            guard sessionIdProvider != nil else { return }
            do {
                try await self?.startNewSession()
            } catch {
                os_log("%{public}@", log: options.log, type: .error, "Starting a new Session with custom Id provider failed with error: \(error)")
            }
        }
        
        appLifecycleManager
            .publisher()
            .sink { [weak self] event in
                self?.transition(to: event)
            }
            .store(in: &cancellables)
    }
    
    var sessionInfo: SessionInfo {
        // Consider using atomic synchronization
        stateQueue.sync() {
            return _sessionInfo
        }
    }

    func publisher() -> AnyPublisher<SessionInfo, Never> {
        subject.eraseToAnyPublisher()
    }
    
    func startNewSession() async throws {
        let oldSession = _sessionInfo
        let newSession = try await sessionManagerInfoProvider.getSessionInfo()
        self._sessionInfo = newSession
        
        let holder = self.subjectHolder
        notificationQueue.async {
            holder.subject.send(newSession)
        }
        
        if options.isDebug {
            os_log("%{public}@", log: options.log, type: .info, "🔄 Session reset: \(oldSession.id) -> \(_sessionInfo.id)")
            let dateInterval = DateInterval(start: oldSession.startTime, end: newSession.startTime)
            os_log("%{public}@", log: options.log, type: .info, "Session duration: \(dateInterval.duration) seconds")
        }
    }
    
    private func transition(to newState: AppLifeCycleEvent) {
            switch newState {
            case .didEnterBackground:
                self.handleBackgroundState()
            case .willEnterForeground:
                self.handleActiveState()
            default:
                break
            }
    }
    
    private func handleActiveState() {
        stateQueue.sync(flags: .barrier) { [weak self] in
            guard let self else { return }

            guard let backgroundTime = self.backgroundTime else { return }
            let timeInBackground = Double(DispatchTime.now().uptimeNanoseconds - backgroundTime.uptimeNanoseconds) / Double(NSEC_PER_SEC)
            if timeInBackground >= self.options.timeout {
                self.resetSession()
            }
            self.backgroundTime = nil
        }
    }
    
    private func handleBackgroundState() {
        stateQueue.sync(flags: .barrier) { [weak self] in
            guard let self else { return }

            self.backgroundTime = DispatchTime.now()
        }
    }
    
    private func resetSession() {
        Task { [weak self] in
            do {
                try await self?.startNewSession()
            } catch {
                os_log("%{public}@", log: options.log, type: .error, "Resetting Session failed with error: \(error)")
            }
        }
        /*
        let oldSession = _sessionInfo
        let newSession = SessionInfo()
        self._sessionInfo = newSession
        
        // Avoid delivering synchronously while on the stateQueue barrier.
        // Dispatch onto a separate queue so subscribers that read `sessionInfo`
        // (which uses `stateQueue.sync`) do not deadlock.
        let holder = self.subjectHolder
        notificationQueue.async {
            holder.subject.send(newSession)
        }
        
        if options.isDebug {
            os_log("%{public}@", log: options.log, type: .info, "🔄 Session reset: \(oldSession.id) -> \(_sessionInfo.id)")
            let dateInterval = DateInterval(start: oldSession.startTime, end: newSession.startTime)
            os_log("%{public}@", log: options.log, type: .info, "Session duration: \(dateInterval.duration) seconds")
        }
        */
    }
}
