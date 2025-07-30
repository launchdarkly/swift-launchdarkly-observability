import Foundation
import Shared

public protocol Session: Sendable {
    var sessionInfo: SessionInfo { get async }
    var sessionContext: SessionContext { get async }
    var sessionId: String { get async }
    func start() async
}

public actor DefaultSession: Session {
    private enum AttributesKey {
        static let sessionId = "session.id"
        static let sessionStartTime = "session.start_time"
    }
    
    public private(set) var sessionInfo: SessionInfo {
        didSet {
            sessionContext = SessionContext(
                sessionId: sessionInfo.sessionId,
                sessionDuration: Date.now.timeIntervalSince1970 - sessionInfo.startTime
            )
        }
    }
    private var backgroundTime: TimeInterval?
    private let options: Options
    public var sessionAttributes: [String: String] {
        [
            AttributesKey.sessionId: sessionInfo.sessionId,
            AttributesKey.sessionStartTime: String(format: "%.0f", sessionInfo.startTime)
        ]
    }
    public private(set) var sessionContext: SessionContext
    
    public var sessionId: String { sessionInfo.sessionId }
    
    public init(
        sessionInfo: SessionInfo = .init(),
        options: Options = .init()
    ) {
        self.sessionInfo = sessionInfo
        self.options = options
        self.sessionContext = .init(sessionId: sessionInfo.sessionId)
    }
    
    public func start() async {
        Task {
            await handleAppBackground()
        }
        Task {
            await handleAppForeground()
        }
    }
    
    private func handleAppBackground() async {
        for await _ in NotificationCenter.default.notifications(for: UIApplication.didEnterBackgroundNotification) {
            backgroundTime = Date.now.timeIntervalSince1970
        }
    }
    
    private func handleAppForeground() async {
        for await _ in NotificationCenter.default.notifications(for: UIApplication.didBecomeActiveNotification) {
            guard let backgroundTime else {
                return
            }
            let timeInBackground = Date.now.timeIntervalSince1970 - backgroundTime
            if timeInBackground >= options.sessionTimeout {
                print("🕐 App was in background for >\(options.sessionTimeout / 60000) minutes, resetting session")
                resetSession()
            }
            self.backgroundTime = nil
        }
    }
    
    private func resetSession() {
        let oldSessionId = sessionInfo.sessionId
        let newSessionId = UUID().uuidString
        
        // TODO: Update resource attributes, since now, thre is a new session
        sessionInfo = .init(sessionId: newSessionId, startTime: Date.now.timeIntervalSince1970)
        print("🔄 Session reset: \(oldSessionId) -> \(sessionInfo.sessionId)")
        if options.environment == .debug {
            print("🔄 Session reset: \(oldSessionId) -> \(sessionInfo.sessionId)")
        }
    }
}
