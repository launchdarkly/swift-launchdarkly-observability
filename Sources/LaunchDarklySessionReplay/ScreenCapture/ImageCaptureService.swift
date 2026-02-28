#if canImport(UIKit)

import UIKit
import Darwin
import Foundation

struct RawCapturedFrame {
    let image: UIImage
    let timestamp: TimeInterval
    let orientation: Int
}

public final class ImageCaptureService {
    private let maskingService = MaskApplier()
    private let maskCollector: MaskCollector
    private let windowCaptureManager = WindowCaptureManager()
    @MainActor
    private var shouldCapture = false
    
    private let scale = 1.0
    
    public init(options: SessionReplayOptions) {
        maskCollector = MaskCollector(privacySettings: options.privacy)
    }
    
    // MARK: - Capture
    
    @MainActor
    public func captureUIImage(yield: @escaping (UIImage?) async -> Void) {
        captureRawFrame { frame in
            await yield(frame?.image)
        }
    }
    
    /// Capture as masked frame (must be on main thread).
    @MainActor
    func captureRawFrame(yield: @escaping (RawCapturedFrame?) async -> Void) {
#if os(iOS)
        let orientation = UIDevice.current.orientation.isLandscape ? 1 : 0
#else
        let orientation = 0
#endif
        let timestamp = Date().timeIntervalSince1970
        let windows = windowCaptureManager.allWindowsInZOrder()
        let enclosingBounds = windowCaptureManager.minimalBoundsEnclosingWindows(windows)
        let renderer = windowCaptureManager.makeRenderer(size: enclosingBounds.size, scale: scale)
        
        CATransaction.flush()
        let maskOperationsBefore = windows.map { maskCollector.collectViewMasks(in: $0, window: $0, scale: scale)  }
        let image = renderer.image { ctx in
            windowCaptureManager.drawWindows(windows, into: ctx.cgContext, bounds: enclosingBounds, afterScreenUpdates: false)
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

                await yield(RawCapturedFrame(image: image, timestamp: timestamp, orientation: orientation))
            }
        }
    }

    @MainActor
    func interuptCapture() {
        shouldCapture = false
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
