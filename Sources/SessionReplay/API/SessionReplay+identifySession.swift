import Foundation

public struct IdentifySessionInput: Encodable {
    public let sessionSecureId: String
    public let userIdentifier: String
    public let userObject: [String: String]?
    
    public init(
        sessionSecureId: String,
        userIdentifier: String,
        userObject: [String: String]? = nil
    ) {
        self.sessionSecureId = sessionSecureId
        self.userIdentifier = userIdentifier
        self.userObject = userObject
    }
    
    enum CodingKeys: String, CodingKey {
        case sessionSecureId = "session_secure_id"
        case userIdentifier  = "user_identifier"
        case userObject      = "user_object"
    }
}

extension SessionReplayAPIService {
    public func identifySession(sessionSecureId: String,
                                userIdentifier: String = "unknown",
                                userObject: [String: String]? = nil) async throws {
        try await gqlClient.executeFromFileIgnoringData(
            resource: "identifySession",
            bundle: Bundle.module,
            variables: IdentifySessionInput(
                sessionSecureId: sessionSecureId,
                userIdentifier: userIdentifier,
                userObject: userObject
            ),
            operationName: "identifySession"
        )
    }
}
