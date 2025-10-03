#if canImport(UIKit)

import UIKit

public struct CapturedImage {
    public let image: UIImage
    public let scale: CGFloat
    public let renderSize: CGSize
}

public final class ScreenCaptureService {
    let maskingService = MaskService()
    let maskCollector: MaskCollector
    
    public init(options: SessionReplayOptions) {
        maskCollector = MaskCollector(privacySettings: options.privacySettings)
    }

    // MARK: - Capture

    /// Capture as UIImage (must be on main thread).
    public func captureUIImage() -> CapturedImage? {
        assert(Thread.isMainThread, "Call on main thread.")
        return captureCompositeImageOfAllWindows()
    }


//    /// Async-style convenience with closure.
//    public func captureUIImage(completion: @escaping (CapturedImage?) -> Void) {
//        runOnMain {
//            completion(self.captureUIImage())
//        }
//    }

    // MARK: - Internals

    private func captureCompositeImageOfAllWindows() -> CapturedImage? {
        let scale = 1.0 // UIScreen.main.scale
        //let bounds  = UIScreen.main.bounds
            
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let windows = allWindowsInZOrder()
        let enclosingBounds = minimalBoundsEnclosingWindows(windows)
        let renderer = UIGraphicsImageRenderer(size: enclosingBounds.size, format: format)
        let image = renderer.image { ctx in
            drawWindows(windows, into: ctx.cgContext, bounds: enclosingBounds, afterScreenUpdates: false, scale: scale)
        }
        
        return CapturedImage(image: image, scale: scale, renderSize: enclosingBounds.size)
    }

    private func allWindowsInZOrder() -> [UIWindow] {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
        let windows = scenes.flatMap { $0.windows }
        return windows
            .filter { !$0.isHidden && $0.alpha > 0 }
            .sorted { $0.windowLevel == $1.windowLevel ? $0.hash < $1.hash : $0.windowLevel < $1.windowLevel }
    }

    private func minimalBoundsEnclosingWindows(_ windows: [UIWindow]) -> CGRect {
        return windows.reduce(into: CGRect.zero) { rect, window in
            rect = rect.enclosing(with: window.frame)
        }
    }
    
    private func drawWindows(_ windows: [UIWindow],
                             into context: CGContext,
                             bounds: CGRect,
                             afterScreenUpdates: Bool,
                             scale: CGFloat) {
        context.saveGState()
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(bounds)
        context.restoreGState()

        for window in windows {
            context.saveGState()
            let maskOperations = maskCollector.collectViewMasks(in: window, window: window, scale: scale)

            context.translateBy(x: window.frame.origin.x, y: window.frame.origin.y)
            context.concatenate(window.transform)

            let anchor = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            context.translateBy(x: anchor.x, y: anchor.y)
            context.translateBy(x: -anchor.x, y: -anchor.y)
            
            let windowFrame = window.layer.frame
            window.drawHierarchy(in: windowFrame, afterScreenUpdates: afterScreenUpdates)
            
            maskingService.applyViewMasks(context: context, operations: maskOperations)
            //window.layer.render(in: context)
            context.restoreGState()
        }
    }

//    private func runOnMain(_ work: @escaping () -> Void) {
//        if Thread.isMainThread { work() } else { DispatchQueue.main.async { work() } }
//    }
}

#endif
