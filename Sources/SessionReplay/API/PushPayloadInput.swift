public struct PushPayloadInput: Codable {
    public struct EventsInput: Codable {
        var events: [Event]
    }

    public struct ErrorInput: Codable {
        
    }
    
    public init(sessionSecureId: String,
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

public struct EventData: Codable {
    var source: IncrementalSource?
    var width: Int?
    var height: Int?
    var node: EventNode?
    var texts = [String]()
    var removes = [String]()
    var adds = [String]()
    var attributes: [String: String]?
    
    public init(source: IncrementalSource? = nil, width: Int? = nil, height: Int? = nil, node: EventNode? = nil, attributes: [String: String]? = nil) {
        self.source = source
        self.width = width
        self.height = height
        self.node = node
        self.attributes = attributes
    }
}

public struct Event: Codable {
    var type: EventType
    var data: EventData
    var timestamp: Int64?
    var _sid: Int
    
    public init(type: EventType, data: EventData, timestamp: Int64? = nil, _sid: Int) {
        self.type = type
        self.data = data
        self.timestamp = timestamp
        self._sid = _sid
    }
}

public struct EventNode: Codable {
    public var id: Int?
    public var type: NodeType
    public var tagName: String
    public var attributes: [String: String]?
    public var childNodes = [EventNode]()

    public init(id: Int? = nil, type: NodeType, tagName: String, attributes: [String : String]? = nil) {
        self.id = id
        self.type = type
        self.tagName = tagName
        self.attributes = attributes
    }
}

public enum EventType: Int, Codable {
    case DomContentLoaded = 0,
         Load = 1,
         FullSnapshot = 2,
         IncrementalSnapshot = 3,
         Meta = 4,
         Custom = 5,
         Plugin = 6
}

public enum NodeType: Int, Codable {
    case Document = 0,
         DocumentType = 1,
         Element = 2,
         Text = 3,
         CDATA = 4,
         Comment = 5
}

public enum IncrementalSource: Int, Codable {
    case mutation = 0,
         mouseMove,
         mouseInteraction,
         scroll,
         viewportResize,
         input,
         touchMove,
         mediaInteraction,
         styleSheetRule,
         canvasMutation,
         font,
         log,
         drag,
         styleDeclaration,
         selection,
         adoptedStyleSheet,
         customElement
}
