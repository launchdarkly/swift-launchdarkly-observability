import Foundation
import UIKit

final class WindowCaptureManager {
    func makeRenderer(size: CGSize, scale: CGFloat) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
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

    func drawWindows(_ windows: [UIWindow],
                     into context: CGContext,
                     bounds: CGRect,
                     afterScreenUpdates: Bool) {
        context.saveGState()
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(bounds)
        context.restoreGState()

        for window in windows {
            context.saveGState()

            context.translateBy(x: window.frame.origin.x, y: window.frame.origin.y)
            context.concatenate(window.transform)
            let anchor = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            context.translateBy(x: anchor.x, y: anchor.y)
            context.translateBy(x: -anchor.x, y: -anchor.y)

            window.drawHierarchy(in: window.layer.frame, afterScreenUpdates: afterScreenUpdates)

            context.restoreGState()
        }
    }
}
