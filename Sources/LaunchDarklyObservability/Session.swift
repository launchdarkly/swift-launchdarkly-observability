import UIKit.UIApplication
import Combine

public final class Session {
    private var id: String
    private var startTime: Date
    private var backgroundTime: Date?
    private var options: SessionOptions
    private var cancellables = Set<AnyCancellable>()
    public var sessionAttributes: [String: String] {
        [
            "session.id": id,
            "session.start_time": String(format: "%.0f", startTime.timeIntervalSince1970)
        ]
    }
    
    public var sessionInfo: SessionInfo {
        .init(
            id: id,
            startTime: startTime
        )
    }
    
    public init(
        id: String = UUID().uuidString,
        startTime: Date = Date.now,
        options: SessionOptions = .init()
    ) {
        self.id = id
        self.startTime = startTime
        self.options = options
    }
    
    public func start(
        onWillEndSession: (@Sendable (_ sessionId: String) -> Void)?,
        onDidStartSession: (@Sendable (_ sessionId: String) -> Void)?
    ) {
        guard let onWillEndSession, let onDidStartSession else { return }
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.backgroundTime = Date.now
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                guard let backgroundTime = self.backgroundTime else {
                    return
                }
                let timeInBackground = Date.now.timeIntervalSince1970 - backgroundTime.timeIntervalSince1970
                if timeInBackground >= self.options.timeout {
                    print("🕐 App was in background for >\(options.timeout / 60000) minutes, resetting session")
                    onWillEndSession(self.sessionInfo.id)
                    self.resetSession()
                    onDidStartSession(self.sessionInfo.id)
                }
                self.backgroundTime = nil
            }
            .store(in: &cancellables)
    }
    
    private func resetSession() {
        let oldSessionId = sessionInfo.id
        let newSessionId = UUID().uuidString
        let oldStartTime = startTime
        
        id = newSessionId
        startTime = Date.now
        if options.isDebug {
            print("🔄 Session reset: \(oldSessionId) -> \(sessionInfo.id)")
            print("Session duration: \(startTime.timeIntervalSince1970 - oldStartTime.timeIntervalSince1970) seconds")
        }
    }
}
