import Foundation

public protocol EventQueueItemPayload {
    func cost() -> Int
    var timestamp: TimeInterval { get }
    var exporterClass: AnyClass { get }
}
