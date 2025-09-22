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
    var timestamp: Int64?
    var _sid: Int
    
    public init(type: EventType, data: AnyEventData, timestamp: Int64? = nil, _sid: Int) {
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

    // We only need "source" to choose the concrete type
    private enum ProbeKey: String, CodingKey { case source }

    init(_ value: any EventDataProtocol) { self.value = value }

    init(from decoder: Decoder) throws {
        let probe = try decoder.container(keyedBy: ProbeKey.self)
        let src = try probe.decode(IncrementalSource.self, forKey: .source)
        if src == .canvasMutation {
            self.value = try CanvasDrawData(from: decoder)
        } else {
            self.value = try EventData(from: decoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        // Delegate to the concrete payload; it must include "source" in its encoding.
        try value.encode(to: encoder)
    }
}
