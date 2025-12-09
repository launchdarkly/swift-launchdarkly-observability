import Foundation
import LaunchDarklyObservability

struct IdentifyItemPayload: EventQueueItemPayload {
    let attributes: [String: String]
    var timestamp: TimeInterval

    var exporterClass: AnyClass {
        SessionReplayExporter.self
    }
    
    func cost() -> Int {
        attributes.count * 100
    }
}
