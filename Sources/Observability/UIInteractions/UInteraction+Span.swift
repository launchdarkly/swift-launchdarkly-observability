import Foundation

struct UIInteractionSpan {
    let attributes: [String: AttributeValue]
    let name: String
    let startTime: Date
    let endTime: Date
}

extension TouchInteraction {
    func span() -> UIInteractionSpan? {
        guard case let .touchDown(point) = kind else { return nil }
        
        var attributes: [String: AttributeValue] = [:]
        attributes["screen.name"] = .string(target?.className ?? "unknown")
        if let accessibilityIdentifier = target?.accessibilityIdentifier {
            attributes["target.id"] = .string(accessibilityIdentifier)
        }
        
        attributes["position.x"] = .string(point.x.toString())
        attributes["position.y"] = .string(point.y.toString())
        
        return UIInteractionSpan(attributes: attributes,
                                 name: "user.tap",
                                 startTime: Date(timeIntervalSince1970: startTimestamp),
                                 endTime: Date(timeIntervalSince1970: timestamp))
    }
}
