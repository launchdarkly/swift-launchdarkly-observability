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
        exportFrame.images.reduce(0) { $0 + $1.data.count }
    }
    
    let exportFrame: ExportFrame
}

//struct ImagesItemPayload: EventQueueItemPayload {
//    var exporterClass: AnyClass {
//        SessionReplayExporter.self
//    }
//    
//    init(exportFrames: [ExportFrame]) {
//        self.exportFrames = exportFrames
//        self.timestamp = exportFrames[0].timestamp
//    }
//    
//    var timestamp: TimeInterval
//    
//    func cost() -> Int {
//        exportFrame.reduce(0) { $0 + $1.data.count }
//    }
//    
//    let exportFrames: [ExportFrame]
//}
