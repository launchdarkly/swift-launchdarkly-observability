import Foundation
import LaunchDarklyObservability

struct ImageItemPayload: EventQueueItemPayload {
    var exporterClass: AnyClass {
        SessionReplayExporter.self
    }
    
    var timestamp: TimeInterval {
        exportImage.timestamp
    }
    
    func cost() -> Int {
        exportImage.data.count
    }
    
    let exportImage: ExportImage
}

struct ImagesItemPayload: EventQueueItemPayload {
    var exporterClass: AnyClass {
        SessionReplayExporter.self
    }
    
    init(exportImages: [ExportImage]) {
        self.exportImages = exportImages
        self.timestamp = exportImages[0].timestamp
    }
    
    var timestamp: TimeInterval
    
    func cost() -> Int {
        exportImages.reduce(0) { $0 + $1.data.count }
    }
    
    let exportImages: [ExportImage]
}
