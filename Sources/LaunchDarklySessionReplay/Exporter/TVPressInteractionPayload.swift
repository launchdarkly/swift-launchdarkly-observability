import Foundation
import LaunchDarklyObservability

/// Queue item for non-spatial `PressInteraction` values (tvOS remote, filtered-window touches, keyboard-sourced presses).
/// Encoded as RRWeb custom events (`RemoteControl`, `Keyboard`) by `RRWebEventGenerator`.
struct TVPressInteractionPayload: EventQueueItemPayload {
    let pressInteraction: PressInteraction

    var timestamp: TimeInterval { pressInteraction.timestamp }

    var exporterClass: AnyClass {
        SessionReplayExporter.self
    }

    func cost() -> Int {
        200
    }
}
