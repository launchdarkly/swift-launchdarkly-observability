import Foundation
import Combine
import Shared

public struct SessionInfo: Sendable, Equatable {
    public let sessionId: String
    public let startTime: TimeInterval
    
    public init(
        sessionId: String = generateUniqueId(),
        startTime: TimeInterval = Date.now.timeIntervalSince1970) {
        self.sessionId = sessionId
        self.startTime = startTime
    }
}

public struct SessionContext: Encodable, Sendable {
    public let sessionId: String
    public let sessionDuration: TimeInterval
    
    init(sessionId: String, sessionDuration: TimeInterval = .zero) {
        self.sessionId = sessionId
        self.sessionDuration = sessionDuration
    }
}

public struct Options: Sendable {
    public enum Environment: String, Hashable, Sendable {
        case debug
    }
    let sessionTimeout: TimeInterval
    let environment: Environment
    
    public init(sessionTimeout: TimeInterval = 30 * 60 * 1000, environment: Options.Environment = .debug) {
        self.sessionTimeout = sessionTimeout
        self.environment = environment
    }
}

public protocol SessionManager: Sendable {
    var sessionInfo: SessionInfo { get async }
    var sessionContext: SessionContext { get async }
    var sessionId: String { get async }
    func start() async
}

public actor StandardSessionManager: SessionManager {
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
    private var cancellables = Set<AnyCancellable>()
    private var backgroundTime: TimeInterval = .zero
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
            let timeInBackground = Date.now.timeIntervalSince1970 - backgroundTime
            if timeInBackground >= options.sessionTimeout {
                print("🕐 App was in background for >\(options.sessionTimeout / 60000) minutes, resetting session")
                resetSession()
            }
            backgroundTime = .zero
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

/*
@SessionActor
public class StandardSessionManager: SessionManager {
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
    private var cancellables = Set<AnyCancellable>()
    private var backgroundTime: TimeInterval = .zero
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
            let timeInBackground = Date.now.timeIntervalSince1970 - backgroundTime
            if timeInBackground >= options.sessionTimeout {
                print("🕐 App was in background for >\(options.sessionTimeout / 60000) minutes, resetting session")
                resetSession()
            }
            backgroundTime = .zero
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
*/

/*
public actor SessionManager {
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
    private var cancellables = Set<AnyCancellable>()
    private var backgroundTime: TimeInterval = .zero
    private let options: Options
    public var sessionAttributes: [String: String] {
        [
            AttributesKey.sessionId: sessionInfo.sessionId,
            AttributesKey.sessionStartTime: String(format: "%.0f", sessionInfo.startTime)
        ]
    }
    public private(set) var sessionContext: SessionContext
    
    var sessionId: String { sessionInfo.sessionId }
    
    public init(
        sessionInfo: SessionInfo = .init(),
        options: Options = .init()
    ) {
        self.sessionInfo = sessionInfo
        self.options = options
        self.sessionContext = .init(sessionId: sessionInfo.sessionId)
    }
    
    public func start() {
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
            let timeInBackground = Date.now.timeIntervalSince1970 - backgroundTime
            if timeInBackground >= options.sessionTimeout {
                print("🕐 App was in background for >\(options.sessionTimeout / 60000) minutes, resetting session")
                resetSession()
            }
            backgroundTime = .zero
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

struct SceneBasedLifeCycle: OptionSet {
    let rawValue: Int
    
    static let unattached = SceneBasedLifeCycle(rawValue: 1 << 0)
    static let foregroundInactive = SceneBasedLifeCycle(rawValue: 1 << 1)
    static let foregroundActive = SceneBasedLifeCycle(rawValue: 1 << 2)
    static let background = SceneBasedLifeCycle(rawValue: 1 << 3)
    static let suspended = SceneBasedLifeCycle(rawValue: 1 << 4)
}

struct AppBasedLifeCycle: OptionSet {
    let rawValue: Int
    
    static let notRunning = AppBasedLifeCycle(rawValue: 1 << 0)
    static let inactive = AppBasedLifeCycle(rawValue: 1 << 1)
    static let active = AppBasedLifeCycle(rawValue: 1 << 2)
    static let background = AppBasedLifeCycle(rawValue: 1 << 3)
    static let suspended = AppBasedLifeCycle(rawValue: 1 << 4)
}

*/
