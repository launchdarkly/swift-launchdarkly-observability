import Foundation

extension TouchInteraction {
    func startEndSpan(tracer: Tracer) {
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
        attributes[SemanticConvention.eventX] = .int(Int(point.x))
        attributes[SemanticConvention.eventY] = .int(Int(point.y))

        let span = tracer.startSpan(name: SemanticConvention.clickSpanName,
                                    attributes: attributes,
                                    startTime: Date(timeIntervalSince1970: startTimestamp),
                                    spanKind: .client)
        span.end(time: Date(timeIntervalSince1970: timestamp))
    }
}
