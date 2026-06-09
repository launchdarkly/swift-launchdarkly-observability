import Foundation

/// A screen appearance broadcast to in-process consumers such as Session Replay.
///
/// Emitted whenever a `screen_view` is recorded, covering both automatic
/// `UIViewController` capture and the manual `trackScreenView` API. Session
/// Replay maps these to RRWeb `Navigate` custom events, mirroring the web SDK
/// where each path change emits `addCustomEvent('Navigate', url)`.
public struct ScreenViewEvent: Sendable {
    /// Human-readable screen name, i.e. the current "route".
    public let name: String
    /// The screen shown immediately before this one, if known.
    public let previousName: String?
    /// Capture time, in seconds since 1970.
    public let timestamp: TimeInterval

    public init(name: String, previousName: String?, timestamp: TimeInterval) {
        self.name = name
        self.previousName = previousName
        self.timestamp = timestamp
    }
}
