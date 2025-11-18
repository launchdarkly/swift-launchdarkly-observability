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
    private let sessionExporterId = ObjectIdentifier(SessionReplayExporter.self)
    
    init(captureService: ScreenCaptureService,
         appLifecycleManager: AppLifecycleManaging,
         eventQueue: EventQueue) {
        self.captureService = captureService
        self.eventQueue = eventQueue
        self.appLifecycleManager = appLifecycleManager
        
        Task(priority: .background) { [weak self, weak eventQueue] in
            guard let self, let eventQueue else { return }
            
            let eventsStream = await eventQueue.events()
            for await event in eventsStream where event.id == sessionExporterId {
                await MainActor.run { [weak self] in
                    switch event.status {
                    case .available:
                        eventQueueAvailable = true
                    case .oveflowed:
                        eventQueueAvailable = false
                    }
                }
            }
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
        guard let displayLink, eventQueueAvailable else {
            return
        }
        
        let now = DispatchTime.now()
        if let lastFrameDispatchTime {
            let timeInBackground = Double(DispatchTime.now().uptimeNanoseconds - lastFrameDispatchTime.uptimeNanoseconds) / Double(NSEC_PER_SEC)
            guard timeInBackground >= frameInterval else {
                return
            }
        }
        
        let lastFrameDispatchTime = DispatchTime.now()
        self.lastFrameDispatchTime = lastFrameDispatchTime
    
        captureService.captureUIImage { capturedImage in
            guard let capturedImage else {
                // dropped frame
                return
            }
            
            guard let exportImage = capturedImage.image.exportImage(format: .jpeg(quality: 0.3),
                                                                    originalSize: capturedImage.renderSize,
                                                                    scale: capturedImage.scale,
                                                                    timestamp: capturedImage.timestamp) else {
                return
            }
            
            await self.eventQueue.send(ScreenImageItem(exportImage: exportImage))
        }
    }
}
