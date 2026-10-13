import Foundation
#if LD_COCOAPODS
    import LaunchDarklyObservability
#else
    import Common
#endif

struct PushPayloadVariables: Codable {
    struct EventsInput: Codable {
        var events: [Event]
    }

    struct ErrorInput: Codable {
        
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

extension PushPayloadVariables: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        writer.beginObject()
        writer.write(CodingKeys.sessionSecureId.rawValue, sessionSecureId)
        writer.write(CodingKeys.payloadId.rawValue, payloadId)
        writer.key(CodingKeys.events.rawValue)
        writer.beginObject()
        writer.write(CodingKeys.events.rawValue, events.events)
        writer.endObject()
        writer.write(CodingKeys.messages.rawValue, messages)
        writer.write(CodingKeys.resources.rawValue, resources)
        writer.write(CodingKeys.webSocketEvents.rawValue, webSocketEvents)
        writer.key(CodingKeys.errors.rawValue)
        writer.beginArray()
        for _ in errors {
            writer.beginObject()
            writer.endObject()
        }
        writer.endArray()
        writer.writeIfPresent(CodingKeys.isBeacon.rawValue, isBeacon)
        writer.writeIfPresent(CodingKeys.hasSessionUnloaded.rawValue, hasSessionUnloaded)
        writer.writeIfPresent(CodingKeys.highlightLogs.rawValue, highlightLogs)
        writer.endObject()
    }

    /// What to reserve for the payload buffer, so a batch of screenshots is not grown and copied as it is written.
    var estimatedJSONByteCount: Int {
        events.events.reduce(0) { $0 + $1.estimatedJSONByteCount }
    }
}

extension SessionReplayAPIService {
    /// The GraphQL body for `pushPayload`, written straight into a byte buffer.
    ///
    /// This is the one request that carries screenshots, and `JSONEncoder` would box the whole batch — every tile as
    /// its own base64 `String` — before writing a byte of it. `PushPayloadEncodingTests` pins the result to what
    /// `GraphQLRequest` would have produced.
    static func pushPayloadBody(_ variables: PushPayloadVariables) -> Data {
        let writer = JSONWriter(reservingCapacity: variables.estimatedJSONByteCount + pushPayloadEnvelopeByteCount)
        writer.beginObject()
        writer.write("query", pushPayloadQuery)
        writer.write("variables", variables)
        writer.write("operationName", pushPayloadOperationName)
        writer.endObject()
        return writer.data
    }

    /// The query, the field names and the fixed string fields, rounded up.
    private static let pushPayloadEnvelopeByteCount = pushPayloadQuery.utf8.count + 1024

    private static let pushPayloadOperationName = "PushPayload"

    func pushPayload(_ variables: PushPayloadVariables) async throws {
        let _: GraphQLEmptyData = try await gqlClient.execute(body: Self.pushPayloadBody(variables))
    }

    private static let pushPayloadQuery = """
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
            """
}
