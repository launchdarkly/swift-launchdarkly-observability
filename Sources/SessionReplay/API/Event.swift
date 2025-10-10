//
//  File.swift
//  swift-launchdarkly-observability
//
//  Created by Andrey Belonogov on 9/19/25.
//

import Foundation

struct Event: Codable {
    var type: EventType
    var data: AnyEventData
    var timestamp: Int64
    var _sid: Int
    
    public init(type: EventType, data: AnyEventData, timestamp: Int64, _sid: Int) {
        self.type = type
        self.data = data
        self.timestamp = timestamp
        self._sid = _sid
    }
}

protocol EventDataProtocol: Codable {
}

struct AnyEventData: Codable {
    let value: any EventDataProtocol

    private enum ProbeKey: String, CodingKey { case source, tag }

    init(_ value: any EventDataProtocol) { self.value = value }

    init(from decoder: Decoder) throws {
        let probe = try decoder.container(keyedBy: ProbeKey.self)
        if let src = try probe.decodeIfPresent(IncrementalSource.self, forKey: .source) {
            if src == .canvasMutation {
                self.value = try CanvasDrawData(from: decoder)
            } else if src == .mouseMove {
                self.value = try MouseMoveEventData(from: decoder)
            } else {
                self.value = try EventData(from: decoder)
            }
        } else if let tag = try probe.decodeIfPresent(CustomDataTag.self, forKey: .tag) {
            self.value = switch tag {
            case .click:
                try CustomEventData<ClickPayload>(from: decoder)
            case .focus:
                try CustomEventData<String>(from: decoder)
            case .viewport:
                try CustomEventData<ViewportPayload>(from: decoder)
            case .reload:
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
