import UIKit

public struct TouchEvent: Sendable, CustomStringConvertible {
    public let location: CGPoint
    public let viewName: String
    public let accessibilityIdentifier: String?
    public let scale: CGFloat
    
    public var locationInPoints: CGPoint {
        return location
    }
    
    public var locationInPixels: CGPoint {
        return CGPoint(x: Int((location.x * scale).rounded()), y: Int((location.y * scale).rounded()))
    }
    
    public var description: String {
        return "TouchEvent(\(location), \(viewName), \(accessibilityIdentifier ?? "nil"), \(scale)) coordinates In pixels: \(locationInPixels.x), \(locationInPixels.y)"
    }
}
