import Foundation
import OpenTelemetryApi

/// A custom analytics `track` event broadcast to in-process consumers such as Session Replay.
///
/// Emitted by the single `track` emitter for every track path — `LDClient.track` (via the
/// observability hook) and the manual ``LDObserve/track(key:properties:metricValue:)`` API, including
/// standalone init without `LDClient`. Session Replay maps these to RRWeb `Custom` events tagged
/// `"Track"`, mirroring the web SDK.
public struct TrackEvent {
    /// The track event key.
    public let name: String
    /// Optional numeric metric value associated with the event.
    public let metricValue: Double?
    /// User-supplied track data attributes (no context keys).
    public let attributes: [String: AttributeValue]
    /// Capture time, in seconds since 1970.
    public let timestamp: TimeInterval

    public init(
        name: String,
        metricValue: Double?,
        attributes: [String: AttributeValue],
        timestamp: TimeInterval
    ) {
        self.name = name
        self.metricValue = metricValue
        self.attributes = attributes
        self.timestamp = timestamp
    }
}
