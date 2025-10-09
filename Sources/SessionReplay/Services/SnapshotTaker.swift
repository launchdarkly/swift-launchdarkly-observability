import Foundation
import ApplicationServices

class SnapshotTaker: EventSource {
    let queue: EventQueue
    let captureService: ScreenCaptureService
    var timer: Timer?
    
    init(queue: EventQueue, captureService: ScreenCaptureService) {
        self.queue = queue
        self.captureService = captureService
    }
    
    func start() {
        guard timer == nil else { return }
        
        let timer = Timer(timeInterval: 1.0, target: self, selector: #selector(queueSnapshot), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .default)
        self.timer = timer
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc func queueSnapshot() {
        guard let capturedImage = captureService.captureUIImage() else {
            return
        }
        
        Task {
            guard let exportImage = capturedImage.image.exportImage(format: .jpeg(quality: 0.3),
                                                                    originalSize: capturedImage.renderSize,
                                                                    scale: capturedImage.scale) else {
                return
            }
            
            await queue.send(EventQueueItem(payload: ScreenImageItem(exportImage: exportImage)))
        }
    }
}
