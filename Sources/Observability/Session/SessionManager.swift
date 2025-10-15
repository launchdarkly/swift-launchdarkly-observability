import Foundation
import UIKit.UIApplication
import OSLog
import OpenTelemetryApi

public protocol SessionManaging {
    var sessionAttributes: [String: AttributeValue] { get }
    var sessionInfo: SessionInfo { get }
    var onSessionDidChange: ((SessionInfo) -> Void)? { get set }
    var onStateDidChange: ((SessionState, SessionInfo) -> Void)? { get set }
}

final class SessionManager: SessionManaging {
    private var id: String
    private var startTime: Date
    private var backgroundTime: Date?
    private var options: SessionOptions
    var sessionAttributes: [String: AttributeValue] {
        [
            "session.id": .string(id),
            "session.start_time": .string(String(format: "%.0f", startTime.timeIntervalSince1970))
        ]
    }
    private let stateQueue = DispatchQueue(
        label: "com.launchdarkly.observability.state-queue",
        attributes: .concurrent)
    
    private var currentState: SessionState = .notRunning
    var onSessionDidChange: ((SessionInfo) -> Void)?
    var onStateDidChange: ((SessionState, SessionInfo) -> Void)?
    
    var sessionInfo: SessionInfo {
        .init(
            id: id,
            startTime: startTime
        )
    }
    
    init(
        id: String = SecureIDGenerator.generateSecureID(),
        startTime: Date = Date(),
        options: SessionOptions
    ) {
        self.id = id
        self.startTime = startTime
        self.options = options
        observeLifecycleNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func observeLifecycleNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
    }
    
    @objc private func handleDidBecomeActive() {
        transition(to: .active)
    }
    
    @objc private func handleWillResignActive() {
        transition(to: .inactive)
    }
    
    @objc private func handleDidEnterBackground() {
        transition(to: .background)
    }
    
    @objc private func handleWillEnterForeground() {
        transition(to: .inactive)
    }
    
    @objc private func handleWillTerminate() {
        transition(to: .notRunning)
    }
    
    private func transition(to newState: SessionState) {
        stateQueue.sync(flags: .barrier) { [weak self] in
            guard let self else { return }
            guard self.currentState != newState else { return }
            self.currentState = newState
            switch newState {
            case .background:
                self.handleBackgroundState()
            case .active:
                self.handleActiveState()
            default:
                break
            }
            self.onStateDidChange?(newState, self.sessionInfo)
        }
    }
    
    private func handleActiveState() {
        guard let backgroundTime = self.backgroundTime else { return }
        let timeInBackground = Date().timeIntervalSince1970 - backgroundTime.timeIntervalSince1970
        if timeInBackground >= self.options.timeout {
            self.resetSession()
        }
        self.backgroundTime = nil
    }
    
    private func handleBackgroundState() {
        self.backgroundTime = Date()
    }
    
    private func resetSession() {
        let oldSessionId = sessionInfo.id
        let newSessionId = SecureIDGenerator.generateSecureID()
        let oldStartTime = startTime
        
        id = newSessionId
        let newStartTime = Date()
        startTime = newStartTime
        
        if options.isDebug {
            os_log("%{public}@", log: options.log, type: .info, "🔄 Session reset: \(oldSessionId) -> \(sessionInfo.id)")
            let dateInterval = DateInterval(start: oldStartTime, end: newStartTime)
            os_log("%{public}@", log: options.log, type: .info, "Session duration: \(dateInterval.duration) seconds")
        }
        onSessionDidChange?(sessionInfo)
    }
}
