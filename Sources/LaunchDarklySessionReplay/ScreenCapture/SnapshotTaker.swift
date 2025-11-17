import Foundation
import LaunchDarklyObservability
import UIKit

final class SnapshotTaker: EventSource {
    private let captureService: ScreenCaptureService
    private let appLifecycleManager: AppLifecycleManaging
    private var displayLink: CADisplayLink?
    private let eventQueue: EventQueue
    private var lastFrameDispatchTime: DispatchTime?
    private let frameInterval = 1.0
    private var eventQueueAvailable: Bool = true
    
    init(captureService: ScreenCaptureService,
         appLifecycleManager: AppLifecycleManaging,
         eventQueue: EventQueue) {
        self.captureService = captureService
        self.eventQueue = eventQueue
        self.appLifecycleManager = appLifecycleManager
        
        Task(priority: .background) { [weak self, weak eventQueue] in
            
        }
        
        Task(priority: .background) { [weak self, weak appLifecycleManager] in
            guard let self, let appLifecycleManager else { return }

            let eventsStream = await appLifecycleManager.events()
            for await event in eventsStream {
                switch event {
                case .didBecomeActive:
                    await MainActor.run { [weak self] in
                        self?.start()
                    }
                case .willResignActive, .willTerminate:
                    await MainActor.run { [weak self] in
                        self?.stop()
                    }
                case .didFinishLaunching, .willEnterForeground, .didEnterBackground:
                    continue
                }
            }
        }
    }
    
    func start() {
        guard displayLink == nil else { return }
        
        let displayLink = CADisplayLink(target: self, selector: #selector(frameUpdate))
        displayLink.add(to: .main, forMode: .common)
        
        self.displayLink = displayLink
    }
    
    @objc private func frameUpdate() {
        queueSnapshot()
    }
    
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    func queueSnapshot() {
        guard let displayLink else {
            return
        }
        
        let now = DispatchTime.now()
        if let lastFrameDispatchTime {
            let timeInBackground = Double(DispatchTime.now().uptimeNanoseconds - lastFrameDispatchTime.uptimeNanoseconds) / Double(NSEC_PER_SEC)
            guard timeInBackground >= frameInterval else {
                return
            }
        }
        lastFrameDispatchTime = DispatchTime.now()
        guard let lastFrameDispatchTime else {
            return
        }
        
        Task {
            // check if buffer is full before doing hard work
            guard await !eventQueue.isFull() else { return }
            
            guard let capturedImage = await captureService.captureUIImage() else {
                self.lastFrameDispatchTime = DispatchTime(uptimeNanoseconds: lastFrameDispatchTime.uptimeNanoseconds - UInt64(Double(NSEC_PER_SEC) / self.frameInterval))
                return
            }
            
            guard let exportImage = capturedImage.image.exportImage(format: .jpeg(quality: 0.3),
                                                                    originalSize: capturedImage.renderSize,
                                                                    scale: capturedImage.scale,
                                                                    timestamp: capturedImage.timestamp) else {
                return
            }
            
            await eventQueue.send(ScreenImageItem(exportImage: exportImage))
        }
    }
}
