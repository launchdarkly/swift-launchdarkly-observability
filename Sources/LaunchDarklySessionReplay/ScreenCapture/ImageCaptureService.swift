#if canImport(UIKit)

import UIKit
import Darwin
import Foundation

public struct CapturedImage {
    public let image: UIImage
    public let scale: CGFloat
    public let rect: CGRect
    public let originalSize: CGSize
    public let timestamp: TimeInterval
    public let orientation: Int
    public let isKeyframe: Bool
}

public final class ImageCaptureService {
    private let maskingService = MaskApplier()
    private let maskCollector: MaskCollector
    private let tiledSignatureManager = TiledSignatureManager()
    private var previousSignature: ImageSignature?
    private var incrementalSnapshots = 0

    private let signatureLock = NSLock()
    @MainActor
    private var shouldCapture = false
    
    private let scale = 1.0
    private let transferMethod: SessionReplayOptions.TransferMethod
    
    public init(options: SessionReplayOptions) {
        maskCollector = MaskCollector(privacySettings: options.privacy)
        transferMethod = options.transferMethod
    }
    
    // MARK: - Capture
    
    /// Capture as UIImage (must be on main thread).
    @MainActor
    public func captureUIImage(yield: @escaping (CapturedImage?) async -> Void) {
#if os(iOS)
        let orientation = UIDevice.current.orientation.isLandscape ? 1 : 0
#else
        let orientation = 0
#endif
        let timestamp = Date().timeIntervalSince1970
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        
        let windows = allWindowsInZOrder()
        let enclosingBounds = minimalBoundsEnclosingWindows(windows)
        let renderer = UIGraphicsImageRenderer(size: enclosingBounds.size, format: format)
        
        CATransaction.flush()
        let maskOperationsBefore = windows.map { maskCollector.collectViewMasks(in: $0, window: $0, scale: scale)  }
        let image = renderer.image { ctx in
            drawWindows(windows, into: ctx.cgContext, bounds: enclosingBounds, afterScreenUpdates: false, scale: scale)
        }
      
        shouldCapture = true // can be set to false from external class to stop capturing work early
        DispatchQueue.main.async { [weak self, weak maskCollector] in
            // Move collecting masks after to the next tick
            guard let self, let maskCollector, shouldCapture else { return }
            
            CATransaction.flush()
            let maskOperationsAfter = windows.map { maskCollector.collectViewMasks(in: $0, window: $0, scale: self.scale)  }
            
            Task {
                guard maskOperationsBefore.count == maskOperationsAfter.count else {
                    await yield(nil)
                    return
                }
                
                var applyOperations = [[MaskOperation]]()
                for (before, after) in zip(maskOperationsBefore, maskOperationsAfter) {
                    if let newOperations = maskCollector.duplicateUnsimilar(before: before, after: after) {
                        applyOperations.append(newOperations)
                    } else {
                        // drop the frame, movement was bigger than mask itself
                        await yield(nil)
                        return
                    }
                }
                
                let image = renderer.image { ctx in
                    image.draw(at: .zero)
                    self.maskingService.applyViewMasks(context: ctx.cgContext, operations: applyOperations.flatMap { $0 })
                }
                
                guard let capturedImage = self.computeDiffCapture(image: image, timestamp: timestamp, orientation: orientation) else {
                    await yield(nil)
                    return
                }

                await yield(capturedImage)
            }
        }
    }
    
    @MainActor
    func interuptCapture() {
        shouldCapture = false
    }
    
    private func computeDiffCapture(image: UIImage, timestamp: TimeInterval, orientation: Int) -> CapturedImage? {
        guard let imageSignature = self.tiledSignatureManager.compute(image: image) else {
            return nil
        }
        
        signatureLock.lock()
        
        guard let diffRect = imageSignature.diffRectangle(other: previousSignature) else {
            signatureLock.unlock()
            return nil
        }
        
        let needWholeScreen = (diffRect.size.width >= image.size.width && diffRect.size.height >= image.size.height)
        let isKeyframe: Bool
        if case .drawTiles(let frameWindow) = transferMethod {
            incrementalSnapshots = (incrementalSnapshots + 1) % frameWindow
            isKeyframe = needWholeScreen || incrementalSnapshots == 0
            if needWholeScreen {
                incrementalSnapshots = 0
            }
        } else {
            isKeyframe = true
        }
            
        signatureLock.unlock()

        let finalRect: CGRect
        var finalImage: UIImage
        
        if isKeyframe {
            finalImage = image
            finalRect = CGRect(x: 0,
                               y: 0,
                               width: image.size.width,
                               height: image.size.height)
          
        } else {
            finalRect = CGRect(x: diffRect.minX,
                                  y: diffRect.minY,
                                  width: min(image.size.width, diffRect.width),
                                  height: min(image.size.height, diffRect.height))
            guard let cropped = image.cgImage?.cropping(to: finalRect) else {
                return nil
            }
            finalImage = UIImage(cgImage: cropped)
        }
        
        let capturedImage = CapturedImage(image: finalImage,
                                          scale: scale,
                                          rect: finalRect,
                                          originalSize: image.size,
                                          timestamp: timestamp,
                                          orientation: orientation,
                                          isKeyframe: isKeyframe)
        previousSignature = imageSignature
        return capturedImage
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

        for (i, window) in windows.enumerated() {
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

// MARK: - Thread CPU Time
private extension ImageCaptureService {
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
