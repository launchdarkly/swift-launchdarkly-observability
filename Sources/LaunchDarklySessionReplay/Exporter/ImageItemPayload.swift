import Foundation
import LaunchDarklyObservability

struct ImageItemPayload: EventQueueItemPayload {
    var exporterClass: AnyClass {
        SessionReplayExporter.self
    }
    
    var timestamp: TimeInterval {
        exportFrame.timestamp
    }
    
    func cost() -> Int {
        exportFrame.addImages.reduce(0) { $0 + $1.data.count }
    }
    
    let exportFrame: ExportFrame
}
