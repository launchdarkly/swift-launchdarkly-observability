#if canImport(UIKit)

import UIKit
import Darwin

public struct CapturedImage {
    public let image: UIImage
    public let scale: CGFloat
    public let renderSize: CGSize
    public let timestamp: TimeInterval
}

public final class ScreenCaptureService {
    let maskingService = MaskApplier()
    let maskCollector: MaskCollector
    
    public init(options: SessionReplayOptions) {
        maskCollector = MaskCollector(privacySettings: options.privacy)
    }
    
    // MARK: - Capture
    
    /// Capture as UIImage (must be on main thread).
    @MainActor
    public func captureUIImage() -> CapturedImage? {
        let scale = 1.0
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        
        let windows = allWindowsInZOrder()
        let enclosingBounds = minimalBoundsEnclosingWindows(windows)
        let renderer = UIGraphicsImageRenderer(size: enclosingBounds.size, format: format)
        var dropFrame = false
        CATransaction.flush()
        var maskOperations = [[MaskOperation]]()
        for window in windows {
            maskOperations.append(maskCollector.collectViewMasks(in: window, window: window, scale: scale))
        }
        
        let image = renderer.image { ctx in
            drawWindows(windows, into: ctx.cgContext, bounds: enclosingBounds, afterScreenUpdates: false, scale: scale)
                
            CATransaction.flush()
            var applyOperations = [[MaskOperation]]()
            for (idx, operations) in maskOperations.enumerated() {
                if let newOperations = maskCollector.duplicateUnsimilar(in: windows[idx], operations: operations, scale: scale) {
                    applyOperations.append(newOperations)
                } else {
                    // drop the frame, movement was bigger than mask itself
                    dropFrame = true
                    return
                }
            }
            
            maskingService.applyViewMasks(context: ctx.cgContext, operations: applyOperations.flatMap { $0 })
        }
        guard !dropFrame else { return nil }
      
        return CapturedImage(image: image,
                             scale: scale,
                             renderSize: enclosingBounds.size,
                             timestamp: Date().timeIntervalSince1970)
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

        for window in windows {
            context.saveGState()
            defer {
                context.restoreGState()
            }
            
            context.translateBy(x: window.frame.origin.x, y: window.frame.origin.y)
            context.concatenate(window.transform)
            let anchor = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            context.translateBy(x: anchor.x, y: anchor.y)
            context.translateBy(x: -anchor.x, y: -anchor.y)

            window.drawHierarchy(in: window.layer.frame, afterScreenUpdates: afterScreenUpdates)
        }
        
        context.restoreGState()
    }
}

// MARK: - Thread CPU Time
private extension ScreenCaptureService {
    /// Measure CPU and wall-clock time for work executed on the current thread.
    /// Returns the closure result alongside CPU and wall elapsed seconds.
    func measureCurrentThreadCPUTime<T>(_ work: () -> T) -> (result: T, cpu: TimeInterval, wall: TimeInterval) {
        let cpuStart = currentThreadCPUTimeSeconds()
        let wallStart = CFAbsoluteTimeGetCurrent()
        let result = work()
        let wallEnd = CFAbsoluteTimeGetCurrent()
        let cpuEnd = currentThreadCPUTimeSeconds()
        return (result, cpuEnd - cpuStart, wallEnd - wallStart)
    }

    func currentThreadCPUTimeSeconds() -> TimeInterval {
        let thread: thread_act_t = mach_thread_self()
        defer { mach_port_deallocate(mach_task_self_, thread) }
        
        var info = thread_basic_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                thread_info(thread, thread_flavor_t(THREAD_BASIC_INFO), intPtr, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        
        let user = info.user_time
        let sys = info.system_time
        let seconds = Double(user.seconds + sys.seconds)
        let microseconds = Double(user.microseconds + sys.microseconds)
        return seconds + (microseconds / 1_000_000)
    }
}

#endif
