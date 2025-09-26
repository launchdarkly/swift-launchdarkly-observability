import Foundation


class ScreenshotManager {
    var queue: EventQueue
    var timer: Timer?
    let captureService = ScreenCaptureService()
    
    init(queue: EventQueue) {
        self.queue = queue
    }
    
    func start() {
        guard timer == nil else { return }
        
        let timer = Timer(timeInterval: 1.0, target: self, selector: #selector(takeScreenshot), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .default)
        self.timer = timer
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc func takeScreenshot() {
        guard let capturedImage = captureService.captureUIImage() else {
            return
        }
        
        Task {
            guard let exportImage = capturedImage.image.exportImage(format: .jpeg(quality: 0.3), originalSize: capturedImage.renderSize, scale: capturedImage.scale) else {
                return
            }
           await queue.enque(EventQueueItem(payload: .screenshot(exportImage: exportImage)))
        }
    }
}
