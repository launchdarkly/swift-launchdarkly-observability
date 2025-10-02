#if canImport(UIKit)

import UIKit
import Common

public final class SwipeHandler {
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
                    let accessibilityIdentifier = targetView.accessibilityIdentifier
                    let targetClass = type(of: targetView)
                    
                    let viewName = accessibilityIdentifier ?? String(describing: targetClass)
                    let touchEvent = TouchEvent(
                        phase: .ended,
                        location: endPoint,
                        viewName: viewName,
                        title: nil,
                        accessibilityIdentifier: accessibilityIdentifier,
                        scale: targetView.window?.screen.scale ?? UIScreen.main.scale)
                    if abs(dx) > 50 && abs(dx) > abs(dy) {
                        /// horizontal swipe
                        completion(touchEvent)
                    } else if abs(dy) > 50 && abs(dy) > abs(dx) {
                        /// vertical swipe
                        completion(touchEvent)
                    }
                }
                startPoint = nil
                
            default:
                break
            }
        }
    }
}

#endif
