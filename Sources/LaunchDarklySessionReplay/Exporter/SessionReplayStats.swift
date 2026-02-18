import Foundation
import OSLog

final class SessionReplayStats {
    private var images: Int = 0
    private var imagesSize: Int64 = 0
    private var firstImageTimestamp: TimeInterval?
    private var lastImageTimestamp: TimeInterval?
    private var statsPublished = DispatchTime.now()
    private var log: OSLog

    init(log: OSLog) {
        self.log = log
    }
    
    var imageFps: Double {
        let elapsedTime = elapsedTime()
        guard elapsedTime > 0 else { return 0 }
        
        return Double(images) / elapsedTime
    }
    
    func addExportFrame(_ exportFrame: ExportFrame) {
        images += 1
        imagesSize += Int64(exportFrame.images.reduce(0) { $0 + $1.data.count })
        firstImageTimestamp = firstImageTimestamp ?? exportFrame.timestamp
        lastImageTimestamp = exportFrame.timestamp
        
        logIfNeeded()
    }
    
    private func elapsedTime() -> TimeInterval {
        guard let firstImageTimestamp, let lastImageTimestamp else { return 0 }
        return (lastImageTimestamp - firstImageTimestamp)
    }
    
    private func report() -> String? {
        guard images > 0 else { return "No images to export." }
        
        var result = "Session Replay Stats:\n"
        result += "images: \(images)\n"
        result += "image total size: \(imagesSize)\n"
        result += "image fps: \(imageFps)\n"
        return result
    }
    
    func logIfNeeded() {
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - statsPublished.uptimeNanoseconds) / Double(NSEC_PER_SEC)
        if elapsed >= 5.0, let reportString = report() {
            os_log("%{public}@", log: log, type: .info, reportString)
            statsPublished = DispatchTime.now()
        }
    }
}
