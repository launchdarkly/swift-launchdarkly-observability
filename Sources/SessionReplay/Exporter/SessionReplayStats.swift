import Foundation

final class SessionReplayStats {
    var images: Int = 0
    var imagesSize: Int64 = 0
    var firstImageTimestamp: TimeInterval?
    var lastImageTimestamp: TimeInterval?

    let start = DispatchTime.now()
   
    var imageFps: Double {
        let elapsedTime = elapsedTime()
        guard elapsedTime > 0 else { return 0 }
        
        return Double(images) / elapsedTime
    }
    
    func addExportImage(_ exportImage: ExportImage) {
        images += 1
        imagesSize += Int64(exportImage.data.count)
        firstImageTimestamp = firstImageTimestamp ?? exportImage.timestamp
        lastImageTimestamp = exportImage.timestamp
    }
    
    func elapsedTime() -> TimeInterval {
        guard let firstImageTimestamp, let lastImageTimestamp else { return 0 }
        return (lastImageTimestamp - firstImageTimestamp)
    }
    
    func report() -> String {
        guard images > 0 else { return "No images to export." }
        
        var result = "Session Replay Stats:\n"
        result += "images: \(images)\n"
        result += "image total size: \(imagesSize)\n"
        result += "image fps: \(imageFps)\n"
        return result
    }
}
