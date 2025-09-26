import Foundation

public struct TouchEvent: Sendable, CustomStringConvertible {
    public enum Phase: Sendable {
        case began, moved, ended
    }

    public let phase: Phase
    public let location: CGPoint
    public let viewName: String?
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

