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
