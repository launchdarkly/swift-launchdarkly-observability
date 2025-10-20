import Foundation

struct UIInteractionSpan {
    let attributes: [String: AttributeValue]
    let name: String
}

extension UIInteraction {
    func span() -> UIInteractionSpan? {
        guard kind.isTapLike else { return nil }
        
        var attributes: [String: AttributeValue] = [:]
        attributes["screen.name"] = .string(target?.className ?? "unknown")
        attributes["target.id"] = .string(target?.accessibilityIdentifier ?? "")
        
        if case let .touchUp(point) = kind {
            attributes["position.x"] = .string(point.x.toString())
            attributes["position.y"] = .string(point.y.toString())
        }
        
        return UIInteractionSpan(attributes: attributes, name: "user.tap")
    }
}
