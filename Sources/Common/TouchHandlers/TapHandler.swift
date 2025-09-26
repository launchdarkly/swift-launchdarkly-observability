import UIKit

public final class TapHandler {
    private var startPoint: CGPoint?
    
    public init() {}
    
    public func handle(event: UIEvent, window: UIWindow, completion: (TouchEvent) -> Void) {
        if let touches = event.allTouches, let touch = touches.first, let targetView = touch.view {
            switch touch.phase {
            case .began:
                startPoint = touch.location(in: window)
            case .ended:
                if let startPoint {
                    let endPoint = touch.location(in: window)
                    let dx = endPoint.x - startPoint.x
                    let dy = endPoint.y - startPoint.y
                    if abs(dx) < 10 && abs(dy) < 10 {
                        let accessibilityIdentifier = targetView.accessibilityIdentifier
                        let targetClass = type(of: targetView)
                        
                        let viewName = accessibilityIdentifier ?? String(describing: targetClass)
                        
                        completion(
                            .init(
                                location: endPoint,
                                viewName: viewName,
                                accessibilityIdentifier: accessibilityIdentifier,
                                scale: targetView.window?.screen.scale ?? UIScreen.main.scale)
                        )
                    }
                }
                startPoint = nil
            default:
                break
            }
        }
    }
}
