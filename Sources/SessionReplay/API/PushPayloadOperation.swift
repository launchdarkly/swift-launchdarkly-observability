import Foundation
import LaunchDarkly
import Common

struct PushPayloadVariables: Codable {
    public struct EventsInput: Codable {
        var events: [Event]
    }

    public struct ErrorInput: Codable {
        
    }
    
    init(sessionSecureId: String,
         payloadId: String,
         events: [Event],
         isBeacon: Bool? = nil,
         hasSessionUnloaded: Bool? = nil,
         highlightLogs: String? = nil) {
        self.sessionSecureId = sessionSecureId
        self.payloadId = payloadId
        self.events = EventsInput(events: events)
        self.isBeacon = isBeacon
        self.hasSessionUnloaded = hasSessionUnloaded
        self.highlightLogs = highlightLogs
    }
    
    var sessionSecureId: String
    var payloadId: String
    var events: EventsInput
    var messages = "{\"messages\":[]}"
    var resources = "{\"resources\":[]}"
    var webSocketEvents = "{\"webSocketEvents\":[]}"
    var errors = [ErrorInput]()
    var isBeacon: Bool?
    var hasSessionUnloaded: Bool?
    var highlightLogs: String?
    
    enum CodingKeys: String, CodingKey {
        case sessionSecureId = "session_secure_id"
        case payloadId = "payload_id"
        case events
        case messages
        case resources
        case webSocketEvents = "web_socket_events"
        case errors
        case isBeacon = "is_beacon"
        case hasSessionUnloaded = "has_session_unloaded"
        case highlightLogs
    }
}

extension SessionReplayAPIService {
    func pushPayload(_ variables: PushPayloadVariables) async throws {
        let _: GraphQLEmptyData = try await gqlClient.executeFromFile(
            resource: "PushPayload",
            bundle: Bundle.module,
            variables: variables,
            operationName: "PushPayload")
    }
}
