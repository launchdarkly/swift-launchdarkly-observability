import Foundation
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
        let _: GraphQLEmptyData = try await gqlClient.execute(
            query: """
                    mutation PushPayload(
                        $session_secure_id: String!
                        $payload_id: ID!
                        $events: ReplayEventsInput!
                        $messages: String!
                        $resources: String!
                        $web_socket_events: String!
                        $errors: [ErrorObjectInput]!
                        $is_beacon: Boolean
                        $has_session_unloaded: Boolean
                        $highlight_logs: String
                    ) {
                        pushPayload(
                            session_secure_id: $session_secure_id
                            payload_id: $payload_id
                            events: $events
                            messages: $messages
                            resources: $resources
                            web_socket_events: $web_socket_events
                            errors: $errors
                            is_beacon: $is_beacon
                            has_session_unloaded: $has_session_unloaded
                            highlight_logs: $highlight_logs
                        )
                    }
            """,
            variables: variables,
            operationName: "PushPayload")
    }
}
