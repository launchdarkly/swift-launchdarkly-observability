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
    /// Stable id (`event.screen_id`) of the active screen at the moment of the tap, read from the live
    /// `ScreenStack` on the main thread when the touch is captured (not later on the background
    /// interpreter/consumer). Travels with the interaction so both the OpenTelemetry `click` span and
    /// the Session Replay click event report the same screen, and so a navigation after the finger
    /// lifts can't misattribute the tap to a later screen.
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
