import Foundation
import UIKit

public struct TouchPoint: Sendable {
    public let position: CGPoint
    public let timestamp: TimeInterval
}

public enum UIInteractionKind: Sendable {
    case touchDown(CGPoint)
    case touchUp(CGPoint)
    case swipe(from: CGPoint, to: CGPoint, swipeDirection: SwipeDirection)
    case touchPath(points: [TouchPoint])
    
    var isTapLike: Bool {
        switch self {
        case .touchDown, .touchUp: return true
        default: return false
        }
    }
}

public struct UIInteraction: Sendable {
    public let id: Int
    public let kind: UIInteractionKind
    public let timestamp: TimeInterval
    public let target: TouchTarget?
}

public enum SwipeDirection: Sendable {
    case left
    case right
    case up
    case down
}
