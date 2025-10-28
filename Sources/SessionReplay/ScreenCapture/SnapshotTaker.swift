import Foundation
import Observability

final class SnapshotTaker: EventSource {
    private let captureService: ScreenCaptureService
    private let appLifecycleManager: AppLifecycleManaging
    private var timer: Timer?
    private let eventQueue: EventQueue
    
    init(captureService: ScreenCaptureService,
         appLifecycleManager: AppLifecycleManaging,
         eventQueue: EventQueue) {
        self.captureService = captureService
        self.eventQueue = eventQueue
        self.appLifecycleManager = appLifecycleManager
        
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
        guard timer == nil else { return }
        
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            queueSnapshot()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func queueSnapshot() {
        guard let timer else {
            return
        }
        
        Task {
            // check if buffer is full before doing hard work
            guard await !eventQueue.isFull() else { return }
            
            guard let capturedImage = await captureService.captureUIImage() else { return }
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
