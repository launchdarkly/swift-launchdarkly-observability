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
    public func initializeSession(context: SessionReplayContext,
                                  sessionSecureId: String,
                                  userIdentifier: String,
                                  userObject: [String: String]? = nil) async throws -> InitializeSessionResponse {
        let clientConfig = InitializeSessionVariables.ClientConfig(
            debug: InitializeSessionVariables.ClientConfig.Debug(
                clientInteractions: true,
                domRecording: true
            ),
            privacySetting: "none",
            serviceName: context.serviceName,
            backendUrl: context.backendUrl,
            manualStart: true,
            organizationID: context.sdkKey,
            environment: "production",
            sessionSecureID: sessionSecureId
        )
        let clientConfigData = try JSONEncoder().encode(clientConfig)
        let clientConfigString = String(data: clientConfigData, encoding: .utf8) ?? "{}"
        
        let session: InitializeSessionSessionData = try await gqlClient.execute(
            query: """
                    fragment MatchParts on MatchConfig {
                        regexValue
                        matchValue
                    }

                    mutation initializeSession(
                        $session_secure_id: String!
                        $organization_verbose_id: String!
                        $enable_strict_privacy: Boolean!
                        $privacy_setting: String!
                        $enable_recording_network_contents: Boolean!
                        $clientVersion: String!
                        $firstloadVersion: String!
                        $clientConfig: String!
                        $environment: String!
                        $id: String!
                        $appVersion: String
                        $serviceName: String!
                        $client_id: String!
                        $network_recording_domains: [String!]
                        $disable_session_recording: Boolean
                    ) {
                        initializeSession(
                            session_secure_id: $session_secure_id
                            organization_verbose_id: $organization_verbose_id
                            enable_strict_privacy: $enable_strict_privacy
                            enable_recording_network_contents: $enable_recording_network_contents
                            clientVersion: $clientVersion
                            firstloadVersion: $firstloadVersion
                            clientConfig: $clientConfig
                            environment: $environment
                            appVersion: $appVersion
                            serviceName: $serviceName
                            fingerprint: $id
                            client_id: $client_id
                            network_recording_domains: $network_recording_domains
                            disable_session_recording: $disable_session_recording
                            privacy_setting: $privacy_setting
                        ) {
                            secure_id
                            project_id
                            sampling {
                                spans {
                                    name {
                                        ...MatchParts
                                    }
                                    attributes {
                                        key {
                                            ...MatchParts
                                        }
                                        attribute {
                                            ...MatchParts
                                        }
                                    }
                                    events {
                                        name {
                                            ...MatchParts
                                        }
                                        attributes {
                                            key {
                                                ...MatchParts
                                            }
                                            attribute {
                                                ...MatchParts
                                            }
                                        }
                                    }
                                    samplingRatio
                                }
                                logs {
                                    message {
                                        ...MatchParts
                                    }
                                    severityText {
                                        ...MatchParts
                                    }
                                    attributes {
                                        key {
                                            ...MatchParts
                                        }
                                        attribute {
                                            ...MatchParts
                                        }
                                    }
                                    samplingRatio
                                }
                            }
                        }
                    }
            """,
            variables: InitializeSessionVariables(
                   sessionSecureId: sessionSecureId,
                   organizationVerboseId:  context.sdkKey,
                   enableStrictPrivacy: false,
                   privacySetting: "none",
                   enableRecordingNetworkContents: false,
                   clientVersion: "9.18.23",
                   firstloadVersion: "9.18.23",
                   clientConfig: clientConfigString,
                   environment: "production",
                   id: "31MMpqmDG2DsZvbxo0Lzx4xelbt7",
                   appVersion: nil,
                   serviceName: context.serviceName,
                   clientId: "31MMpqmDG2DsZvbxo0Lzx4xelbt7",
                   networkRecordingDomains: [],
                   disableSessionRecording: nil
            ),
            operationName: "initializeSession"
        )
        return session.initializeSession
    }
}

