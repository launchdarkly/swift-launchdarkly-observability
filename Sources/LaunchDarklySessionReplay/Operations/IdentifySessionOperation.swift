import Foundation
#if !LD_COCOAPODS
    import Common
#endif

public struct IdentifySessionVariables: Encodable {
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
        try await gqlClient.executeIgnoringData(
            query:
                """
                mutation identifySession(
                    $session_secure_id: String!
                    $user_identifier: String!
                    $user_object: Any
                ) {
                    identifySession(
                        session_secure_id: $session_secure_id
                        user_identifier: $user_identifier
                        user_object: $user_object
                    )
                }
                """,
            variables: IdentifySessionVariables(
                sessionSecureId: sessionSecureId,
                userIdentifier: userIdentifier,
                userObject: userObject
            ),
            operationName: "identifySession"
        )
    }
}
