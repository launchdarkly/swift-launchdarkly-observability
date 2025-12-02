import Foundation
import UIKit.UIApplication
import OSLog
#if !LD_COCOAPODS
    import Common
#endif

public protocol SessionManaging {
    func sessionChanges() async -> AsyncStream<SessionInfo>
    var sessionInfo: SessionInfo { get }
}

final class SessionManager: SessionManaging {
    private let appLifecycleManager: AppLifecycleManaging
    private let options: SessionOptions
    private let broadcaster: Broadcaster<SessionInfo>
    private var _sessionInfo = SessionInfo()
    private var backgroundTime: DispatchTime?
        
    private let stateQueue = DispatchQueue(
        label: "com.launchdarkly.observability.state-queue",
        attributes: .concurrent)
    
    init(options: SessionOptions, appLifecycleManager: AppLifecycleManaging) {
        self.options = options
        self.appLifecycleManager = appLifecycleManager
        self._sessionInfo = SessionInfo()
        self.broadcaster = Broadcaster()
        
        Task(priority: .background) { [weak self, weak appLifecycleManager] in
            guard let self, let appLifecycleManager else { return }

            let eventsStream = await appLifecycleManager.events()
            for await event in eventsStream {
                self.transition(to: event)
            }
        }
    }
    
    var sessionInfo: SessionInfo {
        // Consider using atomic synchronization
        stateQueue.sync() {
            return _sessionInfo
        }
    }

    func sessionChanges() async -> AsyncStream<SessionInfo> {
        await broadcaster.stream()
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
        
        Task {
            await broadcaster.send(newSession)
        }
        
        if options.isDebug {
            os_log("%{public}@", log: options.log, type: .info, "🔄 Session reset: \(oldSession.id) -> \(_sessionInfo.id)")
            let dateInterval = DateInterval(start: oldSession.startTime, end: newSession.startTime)
            os_log("%{public}@", log: options.log, type: .info, "Session duration: \(dateInterval.duration) seconds")
        }
    }
}
