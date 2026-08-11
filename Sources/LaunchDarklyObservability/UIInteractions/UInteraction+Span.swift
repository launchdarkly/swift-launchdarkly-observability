#if !LD_COCOAPODS
import LaunchDarklyOtel
#endif
import Foundation

extension TouchInteraction {
    /// - Parameters:
    ///   - screenId: The current screen's stable id (`event.screen_id`), when known, so the tap
    ///     correlates with the active `screen_view`. Omitted from the span when `nil`.
    ///   - screenName: The current screen's human-readable name (`event.screen_name`), when known.
    ///     Omitted from the span when `nil`.
    func startEndSpan(tracer: Tracer, screenId: String? = nil, screenName: String? = nil) {
        guard case let .touchUp(point) = kind else { return }

        // Per analytics-taxonomy §4.1 `click`: one event for all element types,
        // described through the `event.*` namespace.
        var attributes: [String: AttributeValue] = [:]
        attributes[SemanticConvention.eventType] = .string(SemanticConvention.clickSpanName)
        attributes[SemanticConvention.eventTag] = .string(target?.className ?? "unknown")
        // Prefer an explicit `ldId(...)`; fall back to the accessibility identifier.
        if let id = target?.ldId ?? target?.accessibilityIdentifier {
            attributes[SemanticConvention.eventId] = .string(id)
        }
        if let text = target?.text {
            attributes[SemanticConvention.eventText] = .string(text)
        }
        if let screenId {
            attributes[SemanticConvention.eventScreenId] = .string(screenId)
        }
        if let screenName {
            attributes[SemanticConvention.eventScreenName] = .string(screenName)
        }
        attributes[SemanticConvention.eventX] = .int(Int(point.x))
        attributes[SemanticConvention.eventY] = .int(Int(point.y))

        let span = tracer.startSpan(name: SemanticConvention.clickSpanName,
                                    attributes: attributes,
                                    startTime: Date(timeIntervalSince1970: startTimestamp),
                                    spanKind: .client)
        span.end(time: Date(timeIntervalSince1970: timestamp))
    }
}
