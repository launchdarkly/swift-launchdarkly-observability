import Foundation
import Common

public struct TouchItemPayload: EventQueueItemPayload {
    public let touchEvent: TouchEvent

    public init(touchEvent: TouchEvent) {
        self.touchEvent = touchEvent
    }
    
    public func cost() -> Int {
        300
    }
}
