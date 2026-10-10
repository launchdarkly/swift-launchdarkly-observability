import Foundation

struct Event: Codable {
    var type: EventType
    var data: AnyEventData
    var timestamp: Int64
    var _sid: Int
    
    init(type: EventType, data: AnyEventData, timestamp: TimeInterval, _sid: Int) {
        self.type = type
        self.data = data
        self.timestamp = timestamp.milliseconds
        self._sid = _sid
    }	
}

extension Event: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        writer.beginObject()
        writer.write("type", type)
        writer.write("data", data)
        writer.write("timestamp", timestamp)
        writer.write("_sid", _sid)
        writer.endObject()
    }

    /// Room to reserve for this event in the payload buffer. Only the images are worth estimating: everything else is
    /// a few hundred bytes, while one frame can be megabytes.
    var estimatedJSONByteCount: Int {
        data.value.estimatedJSONByteCount + Event.nonImageByteCountEstimate
    }

    private static let nonImageByteCountEstimate = 512
}

protocol EventDataProtocol: Codable, JSONStreamWritable {
    /// The size of the image payload this carries, if any. Already tracked for the player's canvas budget, and reused
    /// to size the output buffer up front so a multi-megabyte payload is not grown (and copied) a dozen times.
    var estimatedJSONByteCount: Int { get }
}

extension EventDataProtocol {
    var estimatedJSONByteCount: Int { 0 }
}

struct AnyEventData: Codable {
    let value: any EventDataProtocol
    
    private enum ProbeKey: String, CodingKey { case source, tag }

    init(_ value: any EventDataProtocol) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let probe = try decoder.container(keyedBy: ProbeKey.self)
        if let src = try probe.decodeIfPresent(IncrementalSource.self, forKey: .source) {
            if src == .canvasMutation {
                self.value = try CanvasDrawData(from: decoder)
            } else if src == .mouseMove {
                self.value = try MouseMoveEventData(from: decoder)
            } else if src == .mutation {
                self.value = try MutationData(from: decoder)
            } else {
                self.value = try MouseInteractionData(from: decoder)
            }
        } else if let tag = try probe.decodeIfPresent(CustomDataTag.self, forKey: .tag) {
            self.value = switch tag {
            case .click:
                try CustomEventData<ClickPayload>(from: decoder)
            case .focus, .identify:
                try CustomEventData<String>(from: decoder)
            case .viewport:
                try CustomEventData<ViewportPayload>(from: decoder)
            case .reload:
                try CustomEventData<String>(from: decoder)
            case .press:
                try CustomEventData<PressPayload>(from: decoder)
            case .track:
                try CustomEventData<String>(from: decoder)
            case .navigate:
                try CustomEventData<String>(from: decoder)
            case .appForeground, .appBackground:
                try CustomEventData<String>(from: decoder)
            case .appLaunch:
                try CustomEventData<String>(from: decoder)
            }
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Unexpected EventData"))
        }
    }

    func encode(to encoder: Encoder) throws {
        // Delegate to the concrete payload; it must include "source" in its encoding.
        try value.encode(to: encoder)
    }
}

extension AnyEventData: JSONStreamWritable {
    func writeJSON(to writer: JSONWriter) {
        value.writeJSON(to: writer)
    }
}
