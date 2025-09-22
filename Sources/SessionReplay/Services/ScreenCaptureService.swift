import UIKit

struct CapturedImage {
    let image: UIImage
    let scale: CGFloat
    let renderSize: CGSize
}

final class ScreenCaptureService {
    public init() {}

    // MARK: - Capture

    /// Capture as UIImage (must be on main thread).
    func captureUIImage() -> CapturedImage? {
        assert(Thread.isMainThread, "Call on main thread.")
        return captureCompositeImageOfAllWindows()
    }

    /// Async-style convenience with closure.
    public func captureUIImage(completion: @escaping (CapturedImage?) -> Void) {
        runOnMain { completion(self.captureUIImage()) }
    }

    // MARK: - Internals

    private func captureCompositeImageOfAllWindows() -> CapturedImage? {
        let scale = 1.0 // UIScreen.main.scale
        let size  = UIScreen.main.bounds.size

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            drawAllWindows(into: ctx.cgContext)
        }
        return CapturedImage(image: image, scale: scale, renderSize: size)
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

    private func drawAllWindows(into context: CGContext) {
        context.saveGState()
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(UIScreen.main.bounds)
        context.restoreGState()

        for window in allWindowsInZOrder() {
            context.saveGState()
            context.translateBy(x: window.frame.origin.x, y: window.frame.origin.y)
            context.concatenate(window.transform)

            let anchor = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            context.translateBy(x: anchor.x, y: anchor.y)
            context.translateBy(x: -anchor.x, y: -anchor.y)

            window.layer.render(in: context)
            context.restoreGState()
        }
    }

    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async { work() } }
    }
}

