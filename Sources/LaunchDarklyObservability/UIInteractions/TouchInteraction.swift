import Foundation
import UIKit

public struct TouchPoint: Sendable {
    public let position: CGPoint
    public let timestamp: TimeInterval
}

public enum TouchKind: Sendable {
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

public struct TouchInteraction: Sendable {
    public let id: Int
    public let kind: TouchKind
    public let startTimestamp: TimeInterval
    public let timestamp: TimeInterval
    public let target: TouchTarget?
    public let sessionId: String
    /// Stable id (`event.screen_id`) of the active screen at the moment of the tap, stamped from the
    /// live `ScreenStack` when the interaction is captured. Travels with the interaction so both the
    /// OpenTelemetry `click` span and the Session Replay click event report the same screen, instead
    /// of Session Replay lagging on an export-time `Navigate`.
    public var screenId: String? = nil
    /// Human-readable name (`event.screen_name`) of the active screen at the moment of the tap. See
    /// ``screenId``.
    public var screenName: String? = nil
}

public enum SwipeDirection: Sendable {
    case left
    case right
    case up
    case down
}
