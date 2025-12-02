import Foundation
import LaunchDarklyObservability
#if !LD_COCOAPODS
    import Common
#endif

extension TouchInteraction: EventQueueItemPayload {
    public var exporterClass: AnyClass {
        SessionReplayExporter.self
    }
    
    public func cost() -> Int {
        300
    }
}
