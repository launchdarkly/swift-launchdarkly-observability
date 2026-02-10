import Foundation
import Combine
import UIKit.UIApplication
import OSLog
#if !LD_COCOAPODS
    import Common
#endif

public protocol SessionManaging {
    func publisher() -> AnyPublisher<SessionInfo, Never>
    func start(sessionId: String)
    var sessionInfo: SessionInfo { get }
}

final class SessionManager: SessionManaging {
    private let appLifecycleManager: AppLifecycleManaging
    private let options: SessionOptions
    private let subject = PassthroughSubject<SessionInfo, Never>()
    private var _sessionInfo = SessionInfo()
    private var backgroundTime: DispatchTime?
    private var cancellables = Set<AnyCancellable>()
    private let cancellablesQueue = DispatchQueue(label: "com.launchdarkly.observability.cancellables")
    private let notificationQueue = DispatchQueue(label: "com.launchdarkly.observability.session-notifications")
        
    private let stateQueue = DispatchQueue(
        label: "com.launchdarkly.observability.state-queue",
        attributes: .concurrent)
    
    init(options: SessionOptions, appLifecycleManager: AppLifecycleManaging) {
        self.options = options
        self.appLifecycleManager = appLifecycleManager
        self._sessionInfo = SessionInfo()
    }
    
    var sessionInfo: SessionInfo {
        // Consider using atomic synchronization
        get {
            stateQueue.sync() {
                return _sessionInfo
            }
        }
        set {
            stateQueue.sync(flags: .barrier) {
                _sessionInfo = newValue
            }
        }
    }

    func publisher() -> AnyPublisher<SessionInfo, Never> {
        subject.eraseToAnyPublisher()
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
        let oldSession = _sessionInfo
        let newSession = SessionInfo()
        self._sessionInfo = newSession
        
        // Avoid delivering synchronously while on the stateQueue barrier.
        // Dispatch onto a separate queue so subscribers that read `sessionInfo`
        // (which uses `stateQueue.sync`) do not deadlock.
        notificationQueue.async { [weak self] in
            self?.subject.send(newSession)
        }
        
        if options.isDebug {
            os_log("%{public}@", log: options.log, type: .info, "🔄 Session reset: \(oldSession.id) -> \(_sessionInfo.id)")
            let dateInterval = DateInterval(start: oldSession.startTime, end: newSession.startTime)
            os_log("%{public}@", log: options.log, type: .info, "Session duration: \(dateInterval.duration) seconds")
        }
    }
    
    func start(sessionId: String = SecureIDGenerator.generateSecureID()) {
        cancellablesQueue.sync {
            cancellables.removeAll()
            appLifecycleManager
                .publisher()
                .sink { [weak self] event in
                    self?.transition(to: event)
                }
                .store(in: &cancellables)
        }

        let newSessionInfo = SessionInfo(id: sessionId, startTime: Date())
        stateQueue.sync(flags: .barrier) { [weak self] in
            self?._sessionInfo = newSessionInfo
        }
    }

    func stop() {
        cancellablesQueue.sync {
            cancellables.removeAll()
        }
    }
}
