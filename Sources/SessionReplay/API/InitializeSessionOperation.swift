import Foundation

struct InitializeSessionVariables: Codable {
    struct ClientConfig: Codable {
        struct Debug: Codable {
            let clientInteractions: Bool
            let domRecording: Bool
        }

        let debug: Debug
        let privacySetting: String
        let serviceName: String
        let backendUrl: URL
        let manualStart: Bool
        let organizationID: String
        let environment: String
        let sessionSecureID: String
    }
    
    let sessionSecureId: String
    let organizationVerboseId: String
    let enableStrictPrivacy: Bool
    let privacySetting: String
    let enableRecordingNetworkContents: Bool
    let clientVersion: String
    let firstloadVersion: String
    let clientConfig: String
    let environment: String
    let id: String
    let appVersion: String?
    let serviceName: String
    let clientId: String
    let networkRecordingDomains: [String]?
    let disableSessionRecording: Bool?

    enum CodingKeys: String, CodingKey {
        case sessionSecureId = "session_secure_id"
        case organizationVerboseId = "organization_verbose_id"
        case enableStrictPrivacy = "enable_strict_privacy"
        case privacySetting = "privacy_setting"
        case enableRecordingNetworkContents = "enable_recording_network_contents"
        case clientVersion
        case firstloadVersion
        case clientConfig
        case environment
        case id
        case appVersion
        case serviceName
        case clientId = "client_id"
        case networkRecordingDomains = "network_recording_domains"
        case disableSessionRecording = "disable_session_recording"
    }
}

public struct InitializeSessionResponse: Codable {
    public let secureId: String
    
    init(secureId: String) {
        self.secureId = secureId
    }
    
    enum CodingKeys: String, CodingKey {
        case secureId = "secure_id"
    }
}

struct InitializeSessionSessionData: Codable {
    let initializeSession: InitializeSessionResponse
}

struct InitializeSessionResponseWrapper: Codable {
    let data: InitializeSessionSessionData
}


extension SessionReplayAPIService {
    public func initializeSession(sessionSecureId: String,
                                  userIdentifier: String = "unknown",
                                  userObject: [String: String]? = nil) async throws -> InitializeSessionResponse {
        let clientConfig = InitializeSessionVariables.ClientConfig(
            debug: InitializeSessionVariables.ClientConfig.Debug(
                clientInteractions: true,
                domRecording: true
            ),
            privacySetting: "none",
            serviceName: "ryan-test",
            backendUrl: URL(string: "https://pub.observability.ld-stg.launchdarkly.com")!,
            manualStart: true,
            organizationID: "548f6741c1efad40031b18ae",
            environment: "production",
            sessionSecureID: sessionSecureId
        )
        let clientConfigData = try JSONEncoder().encode(clientConfig)
        let clientConfigString = String(data: clientConfigData, encoding: .utf8) ?? "{}"
        
        let session: InitializeSessionSessionData = try await gqlClient.executeFromFile(
            resource: "initializeSession",
            bundle: Bundle.module,
            variables: InitializeSessionVariables(
                   sessionSecureId: sessionSecureId,
                   organizationVerboseId: "548f6741c1efad40031b18ae",
                   enableStrictPrivacy: false,
                   privacySetting: "none",
                   enableRecordingNetworkContents: false,
                   clientVersion: "9.18.23",
                   firstloadVersion: "9.18.23",
                   clientConfig: clientConfigString,
                   environment: "production",
                   id: "31MMpqmDG2DsZvbxo0Lzx4xelbt7",
                   appVersion: nil,
                   serviceName: "ryan-test",
                   clientId: "31MMpqmDG2DsZvbxo0Lzx4xelbt7",
                   networkRecordingDomains: [],
                   disableSessionRecording: nil
            ),
            operationName: "initializeSession"
        )
        return session.initializeSession
    }
}

