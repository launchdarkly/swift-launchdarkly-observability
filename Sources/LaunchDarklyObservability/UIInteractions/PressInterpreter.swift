import Foundation

final class PressInterpreter {
    func process(pressInteraction: PressInteraction, yield: PressInteractionYield) {
        let uptimeDifference = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        let corrected = PressInteraction(
            phase: pressInteraction.phase,
            kind: pressInteraction.kind,
            timestamp: pressInteraction.timestamp + uptimeDifference,
            target: pressInteraction.target
        )
        yield(corrected)
    }
}
