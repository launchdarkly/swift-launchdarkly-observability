import Foundation

extension TouchInteraction {
    func startEndSpan(tracer: Tracer) {
        guard case let .touchUp(point) = kind else { return }
        
        var attributes: [String: AttributeValue] = [:]
        attributes["screen.name"] = .string(target?.className ?? "unknown")
        if let accessibilityIdentifier = target?.accessibilityIdentifier {
            attributes["target.id"] = .string(accessibilityIdentifier)
        }
        
        attributes["position.x"] = .string(point.x.toString())
        attributes["position.y"] = .string(point.y.toString())
        
        let span = tracer.startSpan(name: "user.tap",
                                    attributes: attributes,
                                    startTime: Date(timeIntervalSince1970: startTimestamp))
        span.end(time: Date(timeIntervalSince1970: timestamp))
    }
}
