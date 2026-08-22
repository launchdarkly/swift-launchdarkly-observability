import Foundation
import OpenTelemetryApi

/// An identified context broadcast to in-process consumers such as Session Replay.
///
/// Emitted by the single identify funnel for every path — `LDClient.identify` (via the
/// observability hook) and the manual ``LDObserve/identify(contextKeys:canonicalKey:attributes:)``
/// API, including standalone init without `LDClient`. Session Replay maps these to an
/// `identifySession` call and an RRWeb `Identify` event.
public struct IdentifyEvent {
    /// Context kind -> key pairs for the identified context. A single-kind identify made through
    /// ``LDObserve/identify(key:attributes:)`` carries just `["user": key]`.
    public let contextKeys: [String: String]
    /// The fully qualified context key, used as the session's user identifier.
    public let canonicalKey: String
    /// Caller-supplied identity attributes, if any. Unlike ``contextKeys`` these are not stamped
    /// onto later spans; they describe the identity itself.
    public let attributes: [String: AttributeValue]
    /// Identify time, in seconds since 1970.
    public let timestamp: TimeInterval

    public init(
        contextKeys: [String: String],
        canonicalKey: String,
        attributes: [String: AttributeValue],
        timestamp: TimeInterval
    ) {
        self.contextKeys = contextKeys
        self.canonicalKey = canonicalKey
        self.attributes = attributes
        self.timestamp = timestamp
    }
}
