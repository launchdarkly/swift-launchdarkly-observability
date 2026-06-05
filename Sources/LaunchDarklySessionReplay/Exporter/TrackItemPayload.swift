import Foundation
import LaunchDarklyObservability

/// Session-replay queue item for a custom analytics `track` event.
///
/// Mirrors the web SDK, where `LDClient.track` -> `afterTrack` hook -> `RecordSDK.track`
/// emits an rrweb `Custom` event tagged `"Track"`. On iOS the LD `afterTrack` hook routes
/// here so the same timeline event is produced in the replay.
struct TrackItemPayload: EventQueueItemPayload {
    let name: String
    let value: Double?
    let attributes: [String: String]
    var timestamp: TimeInterval
    let sessionId: String

    var exporterClass: AnyClass {
        SessionReplayExporter.self
    }

    func cost() -> Int {
        (attributes.count + 1) * 100
    }
}

extension TrackItemPayload {
    init(name: String,
         value: Double?,
         attributes: [String: AttributeValue],
         timestamp: TimeInterval,
         sessionId: String) {
        self.name = name
        self.value = value
        self.attributes = attributes.compactMapValues { Self.stringValue(from: $0) }
        self.timestamp = timestamp
        self.sessionId = sessionId
    }

    private static func stringValue(from value: AttributeValue) -> String? {
        switch value {
        case .array, .set, .boolArray, .intArray, .doubleArray, .stringArray:
            return nil
        case .string(let v):
            return v
        case .bool(let v):
            return v.description
        case .int(let v):
            return String(v)
        case .double(let v):
            return String(v)
        }
    }
}
