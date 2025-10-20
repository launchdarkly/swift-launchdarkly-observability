import Foundation
import Observability

typealias ExportImageYield = @Sendable (ExportImage) async -> Void

class SnapshotTaker: EventSource {
    let captureService: ScreenCaptureService
    var timer: Timer?
    private let yield: ExportImageYield

    init(captureService: ScreenCaptureService, yield: @escaping ExportImageYield) {
        self.captureService = captureService
        self.yield = yield
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
                                                                    scale: capturedImage.scale,
                                                                    timestamp: capturedImage.timestamp) else {
                return
            }
            
            await yield(exportImage)
        }
    }
}
