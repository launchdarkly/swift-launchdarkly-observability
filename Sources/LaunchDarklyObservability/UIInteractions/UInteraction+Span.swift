import Foundation

/// Builds the `event.*` attributes for a `click` span (taxonomy §4.1), shared by the manual
/// `trackClick` API. Applied in increasing precedence so the taxonomy can never be clobbered:
/// caller `properties` first, then `contextKeyAttributes`, then the reserved `event.*` fields
/// last. Optional values are omitted when `nil`; `event.type` is always present.
enum ClickAttributes {
    static func build(
        id: String?,
        tag: String?,
        text: String?,
        screenId: String?,
        x: Int?,
        y: Int?,
        contextKeyAttributes: [String: AttributeValue] = [:],
        properties: [String: AttributeValue] = [:]
    ) -> [String: AttributeValue] {
        var attributes: [String: AttributeValue] = [:]
        for (k, v) in properties {
            attributes[k] = v
        }
        for (k, v) in contextKeyAttributes {
            attributes[k] = v
        }
        attributes[SemanticConvention.eventType] = .string(SemanticConvention.clickSpanName)
        if let tag {
            attributes[SemanticConvention.eventTag] = .string(tag)
        }
        if let id {
            attributes[SemanticConvention.eventId] = .string(id)
        }
        if let text {
            attributes[SemanticConvention.eventText] = .string(text)
        }
        if let screenId {
            attributes[SemanticConvention.eventScreenId] = .string(screenId)
        }
        if let x {
            attributes[SemanticConvention.eventX] = .int(x)
        }
        if let y {
            attributes[SemanticConvention.eventY] = .int(y)
        }
        return attributes
    }
}

extension TouchInteraction {
    /// - Parameter screenId: The current screen's stable id (`event.screen_id`), when known,
    ///   so the tap correlates with the active `screen_view`. Omitted from the span when `nil`.
    func startEndSpan(tracer: Tracer, screenId: String? = nil) {
        guard case let .touchUp(point) = kind else { return }

        // Per analytics-taxonomy §4.1 `click`: one event for all element types,
        // described through the `event.*` namespace.
        var attributes: [String: AttributeValue] = [:]
        attributes[SemanticConvention.eventType] = .string(SemanticConvention.clickSpanName)
        attributes[SemanticConvention.eventTag] = .string(target?.className ?? "unknown")
        if let accessibilityIdentifier = target?.accessibilityIdentifier {
            attributes[SemanticConvention.eventId] = .string(accessibilityIdentifier)
        }
        if let text = target?.text {
            attributes[SemanticConvention.eventText] = .string(text)
        }
        if let screenId {
            attributes[SemanticConvention.eventScreenId] = .string(screenId)
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
