import Foundation


public enum UIInteractionKind: Sendable {
    case touchDown
    case touchUp
    case tap
    case swipe(from: CGPoint, to: CGPoint, swipeDirection: SwipeDirection)
    case touchPath(points: [CGPoint])
}

public struct UIInteraction: Sendable {
    public let kind: UIInteractionKind
    public let sceneId: String?
    public let timestamp: TimeInterval
    public let target: TouchTarget
}

public enum SwipeDirection: Sendable {
    case left
    case right
    case up
    case down
}

public struct TouchTarget: Sendable {
    public let className: String?
    public let accessibilityIdentifier: String?
    public let isAccessibilityElement: Bool?
    public let rectInWindow: CGRect
    public let rectOnScreen: CGRect
    public let rowIndex: IndexPath?
}


public struct TouchSample: Sendable, CustomStringConvertible {
    public enum Phase: Sendable {
        case down, move, up, cancel
    }
    
    public let phase: Phase
    public let id: ObjectIdentifier
    public let location: CGPoint
    public let timestamp: TimeInterval
    public weak var leavView: UIView?
    public weak window: UIWindow?
    
    public init(touch: UITouch, window: UIWindow) {
        self.id = ObjectIdentifier(touch)
        self.location = touch.location(in: window)
        self.timestamp = touch.timestamp
        self.leavView = touch.view
        self.window = window
        
        self.phase = switch (touch.phase) {
        case .began: .down
        case .moved, .stationary: .move
        case .ended: .up
        case .cancelled: .cancel
        @unknown default: .move
        }
    }
}


public struct TouchEvent: Sendable, CustomStringConvertible {
    public enum Phase: Sendable {
        case began, moved, ended
    }
    
    public let phase: Phase
    public let location: CGPoint
    public let viewName: String?
    public let title: String?
    public let accessibilityIdentifier: String?
    public let scale: CGFloat
    
    public var locationInPoints: CGPoint {
        return location
    }
    
    public var locationInPixels: CGPoint {
        return CGPoint(x: (location.x * scale).rounded(), y: (location.y * scale).rounded())
    }
    
    public var description: String {
        return "TouchEvent(\(location), \(viewName ?? "nil"), \(accessibilityIdentifier ?? "nil"), \(scale)) coordinates In pixels: \(locationInPixels.x), \(locationInPixels.y)"
    }
}
