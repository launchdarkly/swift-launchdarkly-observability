import Foundation

public protocol EventQueueItemPayload {
    func cost() -> Int
}
