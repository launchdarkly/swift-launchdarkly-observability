import UIKit.UIWindow
import Common

public final class TapHandler {
    private var startPoint: CGPoint?
    
    public init() {}
    
    public func handle(event: UIEvent, window: UIWindow, completion: (TouchEvent) -> Void) {
        if let touches = event.allTouches, let touch = touches.first, let targetView = touch.view {
            switch touch.phase {
            case .began:
                startPoint = touch.location(in: window)
                if let startPoint {
                    completion(
                        TouchEvent(
                            phase: touch.phase,
                            location: startPoint,
                            viewName: nil,
                            accessibilityIdentifier: nil,
                            scale: targetView.window?.screen.scale ?? UIScreen.main.scale)
                    )
                }
            case .ended:
                if let startPoint {
                    let endPoint = touch.location(in: window)
                    let dx = endPoint.x - startPoint.x
                    let dy = endPoint.y - startPoint.y
                    var viewName: String?
                    var accessibilityIdentifier: String?
                    var targetClass: AnyClass?
                    if abs(dx) < 10 && abs(dy) < 10 {
                        accessibilityIdentifier = targetView.accessibilityIdentifier
                        targetClass = type(of: targetView)
                        viewName = accessibilityIdentifier ?? String(describing: targetClass)
                    }
                    completion(
                        TouchEvent(
                            phase: touch.phase,
                            location: endPoint,
                            viewName: viewName,
                            accessibilityIdentifier: accessibilityIdentifier,
                            scale: targetView.window?.screen.scale ?? UIScreen.main.scale)
                    )
                }
                startPoint = nil
            default:
                break
            }
        }
    }
}
