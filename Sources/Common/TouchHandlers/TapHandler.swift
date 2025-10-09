#if canImport(UIKit)

import UIKit.UIWindow

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
                            phase: .began,
                            location: startPoint,
                            viewName: nil,
                            title: nil,
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
                    var title: String?
                    if abs(dx) < 10 && abs(dy) < 10 {
                        let info = targetView.extractViewInfo()
                        viewName = info.category
                    }
                    completion(
                        TouchEvent(
                            phase: .ended,
                            location: endPoint,
                            viewName: viewName,
                            title: title,
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

#endif
