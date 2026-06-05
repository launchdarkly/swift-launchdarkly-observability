import Foundation
import LaunchDarklyObservability

/// Session-replay queue item for a screen change (or first screen).
///
/// Mirrors the web SDK, where each path change emits an rrweb `Custom` event
/// tagged `"Navigate"` with the URL as a string payload. On iOS the "route" is
/// the screen name, sourced from the observability screen-view stream.
struct NavigateItemPayload: EventQueueItemPayload {
    let name: String
    var timestamp: TimeInterval
    let sessionId: String

    var exporterClass: AnyClass {
        SessionReplayExporter.self
    }

    func cost() -> Int {
        100
    }
}
