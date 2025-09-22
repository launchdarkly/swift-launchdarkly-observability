import Foundation
import Common
import UIKit

struct EventQueueItem {
    enum Payload {
        case screenshot(exportImage: ExportImage)
        case tap(touch: TouchEvent)
    }
    
    var payload: Payload
    var date: Date
    
    init(payload: Payload, date: Date = Date()) {
        self.payload = payload
        self.date = date
    }
    
    var timestamp: Int64 {
        Int64(date.timeIntervalSince1970 * 1000.0)
    }
}

// TODO: make it optimal
actor EventQueue {
    var storage = [EventQueueItem]()
    
    func enque(_ item: EventQueueItem) {
        storage.append(item)
    }
     
    func dequeue() -> EventQueueItem? {
        guard !storage.isEmpty else {
            return nil
        }
        // TODO: verify that is O(1) in this case
        return storage.removeFirst()
    }
    
    func dequeue(count: Int) -> [EventQueueItem] {
        guard !storage.isEmpty else {
            return []
        }
        
        let availableCount = min(count, storage.count)
        let result = Array(storage[0..<availableCount])
        // TODO: verify that is O(count) in this case if not use another structure
        storage.removeFirst(availableCount)
        return result
    }
}
