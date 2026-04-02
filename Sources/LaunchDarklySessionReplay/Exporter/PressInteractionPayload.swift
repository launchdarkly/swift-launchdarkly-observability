import Foundation
import LaunchDarklyObservability

/// Queue item for non-spatial `PressInteraction` values (remote control, filtered-window touches, keyboard-sourced presses).
/// Encoded as RRWeb custom events (`RemoteControl`, `Keyboard`) by `RRWebEventGenerator`.
struct PressInteractionPayload: EventQueueItemPayload {
    let pressInteraction: PressInteraction

    var timestamp: TimeInterval { pressInteraction.timestamp }

    var exporterClass: AnyClass {
        SessionReplayExporter.self
    }

    func cost() -> Int {
        200
    }
}
