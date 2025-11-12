import Foundation
import Common
import LaunchDarklyObservability

extension TouchInteraction: EventQueueItemPayload {
    public var exporterClass: AnyClass {
        SessionReplayExporter.self
    }
    
    public func cost() -> Int {
        300
    }
}
