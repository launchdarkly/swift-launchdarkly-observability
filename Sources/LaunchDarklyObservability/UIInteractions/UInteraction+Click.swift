#if !LD_COCOAPODS
import LaunchDarklyOtel
#endif
import Foundation

extension TouchInteraction {
    /// Describes this interaction as a taxonomy `click` (§4.1), or `nil` when it isn't one.
    ///
    /// Only a completed tap is a click, so anything but a touch-up is ignored. The result goes to the
    /// pipeline's single click emitter, which fans it out to both the OpenTelemetry `click` span and
    /// the Session Replay `Click` event.
    ///
    /// - Parameters:
    ///   - screenId: The current screen's stable id (`event.screen_id`), when known, so the click
    ///     correlates with the active `screen_view`. Omitted when `nil`.
    ///   - screenName: The current screen's human-readable name (`event.screen_name`), when known.
    ///     Omitted when `nil`.
    func clickEvent(screenId: String? = nil, screenName: String? = nil) -> ClickEvent? {
        guard case let .touchUp(point) = kind else { return nil }

        // A tap the embedder already owns (Flutter resolves it in its own widget tree and reports it
        // via `trackClick`) carries no target, so reporting it here would duplicate that click as an
        // unhelpful `FlutterView`.
        if target?.embedderOwned == true { return nil }

        return ClickEvent(
            tag: target?.className ?? "unknown",
            // Prefer an explicit `ldId(...)`; fall back to the accessibility identifier.
            id: target?.ldId ?? target?.accessibilityIdentifier,
            text: target?.text,
            screenId: screenId,
            screenName: screenName,
            x: Int(point.x),
            y: Int(point.y),
            timestamp: timestamp,
            // Time the span across the whole press, touch-down to touch-up.
            startTimestamp: startTimestamp
        )
    }
}
