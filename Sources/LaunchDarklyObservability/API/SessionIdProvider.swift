import Foundation

public protocol SessionIdProvider: Sendable {
    func generateSessionId() async throws -> String
}

protocol SessionInfoProvider: Sendable {
    func getSessionInfo() async throws -> SessionInfo
}

typealias SessionManagerInfoProvider = SessionIdProvider & SessionInfoProvider

actor LaunchDarklySessionIdProvider: SessionIdProvider {
    func generateSessionId() async throws -> String {
        SecureIDGenerator.generateSecureID()
    }
}

actor LaunchDarklySessionInfoProvider: SessionManagerInfoProvider {
    private let sessionIdProvider: SessionIdProvider
    
    init(sessionIdProvider: SessionIdProvider = LaunchDarklySessionIdProvider()) {
        self.sessionIdProvider = sessionIdProvider
    }
    
    func generateSessionId() async throws -> String {
        try await sessionIdProvider.generateSessionId()
    }
    
    func getSessionInfo() async throws -> SessionInfo {
        .init(
            id: try await generateSessionId(),
            startTime: Date()
        )
    }
}
