import Foundation
import LaunchDarklyObservability

/// Session-replay queue item for a click.
///
/// Mirrors the web SDK, where each click emits an rrweb `Custom` event tagged `"Click"`. Sourced
/// from the observability click stream, so it covers automatically detected taps as well as clicks
/// reported through `LDObserve.trackClick` — the path used by embedders such as Flutter, whose UI is
/// a single native view that no native hit-test can look inside.
struct ClickItemPayload: EventQueueItemPayload {
    let click: ClickEvent
    var timestamp: TimeInterval
    let sessionId: String

    var exporterClass: AnyClass {
        SessionReplayExporter.self
    }

    func cost() -> Int {
        100
    }
}
