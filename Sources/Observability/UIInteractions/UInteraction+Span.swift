import Foundation

struct UIInteractionSpan {
    let attributes: [String: AttributeValue]
    let name: String
}

extension TouchInteraction {
    func span() -> UIInteractionSpan? {
        guard kind.isTapLike else { return nil }
        
        var attributes: [String: AttributeValue] = [:]
        attributes["screen.name"] = .string(target?.className ?? "unknown")
        if let accessibilityIdentifier = target?.accessibilityIdentifier {
            attributes["target.id"] = .string(accessibilityIdentifier)
        }
        
        if case let .touchUp(point) = kind {
            attributes["position.x"] = .string(point.x.toString())
            attributes["position.y"] = .string(point.y.toString())
        } else if case let .touchDown(point) = kind {
            attributes["position.x"] = .string(point.x.toString())
            attributes["position.y"] = .string(point.y.toString())
        }
        
        return UIInteractionSpan(attributes: attributes, name: "user.tap")
    }
}
