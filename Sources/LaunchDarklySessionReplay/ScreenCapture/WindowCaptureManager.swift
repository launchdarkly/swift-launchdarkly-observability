import Foundation
import UIKit

final class WindowCaptureManager {
    func makeRenderer(size: CGSize, scale: CGFloat) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format)
    }

    func allWindowsInZOrder() -> [UIWindow] {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
        let windows = scenes.flatMap { $0.windows }
        return windows
            .filter { !$0.isHidden && $0.alpha > 0 }
            .sorted { $0.windowLevel == $1.windowLevel ? $0.hash < $1.hash : $0.windowLevel < $1.windowLevel }
    }

    func minimalBoundsEnclosingWindows(_ windows: [UIWindow]) -> CGRect {
        return windows.reduce(into: CGRect.zero) { rect, window in
            rect = rect.enclosing(with: window.frame)
        }
    }

#if os(tvOS)
    private static func findFocusedView(in view: UIView) -> UIView? {
        for subview in view.subviews {
            if let focused = findFocusedView(in: subview) {
                return focused
            }
        }
        return view.isFocused ? view : nil
    }
#endif

    func drawWindows(_ windows: [UIWindow],
                     into context: CGContext,
                     bounds: CGRect,
                     afterScreenUpdates: Bool) {
        context.saveGState()
#if os(tvOS)
        context.setFillColor(UIColor.black.cgColor)
#else
        context.setFillColor(UIColor.clear.cgColor)
#endif
        context.fill(bounds)
        context.restoreGState()

        for window in windows {
            context.saveGState()

            context.translateBy(x: window.frame.origin.x, y: window.frame.origin.y)
            context.concatenate(window.transform)
            let anchor = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            context.translateBy(x: anchor.x, y: anchor.y)
            context.translateBy(x: -anchor.x, y: -anchor.y)

#if os(tvOS)
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false
            format.preferredRange = .standard
            
            // 1. layer.render gives perfect unselected rows, but missing focus highlight
            let layerImage = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { ctx in
                window.layer.render(in: ctx.cgContext)
            }
            
            // 2. drawHierarchy gives perfect focused row, but broken unselected rows
            let hierarchyImage = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { ctx in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
            }
            
            if let focusedView = Self.findFocusedView(in: window) {
                let focusedLayer = focusedView.layer.presentation() ?? focusedView.layer
                
                // Get the exact frame of the focused row on screen
                let focusedFrame = window.layer.convert(focusedLayer.bounds, from: focusedLayer)
                // Expand by 40pt to include the scale-up effect, shadow, and glowing focus highlight
                let cutoutFrame = focusedFrame.insetBy(dx: -40, dy: -40)
                
                context.saveGState()
                
                // Draw the perfect focused row (and the broken unselected rows)
                hierarchyImage.draw(in: window.bounds)
                
                // Create a clipping mask that has a hole exactly where the focused row is
                context.beginPath()
                context.addRect(window.bounds)
                context.addRect(cutoutFrame)
                context.clip(using: .evenOdd)
                
                // Draw the perfect unselected rows everywhere else (ignoring the hole)
                layerImage.draw(in: window.bounds)
                
                context.restoreGState()
            } else {
                layerImage.draw(in: window.bounds)
            }
#else
            window.drawHierarchy(in: window.layer.frame, afterScreenUpdates: afterScreenUpdates)
#endif

            context.restoreGState()
        }
    }
}
