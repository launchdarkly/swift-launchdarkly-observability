import Foundation
import Common

struct EventQueueItem {
    enum Payload {
        case screenshot(exportImage: ExportImage)
        case tap(touch: TouchEvent)
    }
    
    var payload: Payload
    var timeIntervalSince1970: TimeInterval

    
    init(payload: Payload, date: Date = Date()) {
        self.payload = payload
        self.timeIntervalSince1970 = date.timeIntervalSince1970
    }
    
    var timestamp: Int64 {
        Int64(timeIntervalSince1970 * 1000.0)
    }
    
    func cost() -> Int {
        switch payload {
        case .screenshot(let exportImage):
            return exportImage.data.count
        case .tap:
            return 300
        }
    }
}

// TODO: make it optimal
actor EventQueue {
    var storage = [EventQueueItem]()
    var lastEventTime: TimeInterval = 0
    
    func enque(_ item: EventQueueItem) {
        storage.append(item)
        lastEventTime = item.timeIntervalSince1970
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
    
    func dequeue(cost: Int, limit: Int) -> [EventQueueItem] {
        guard !storage.isEmpty else {
            return []
        }
        
        var result = [EventQueueItem]()
        var sumCost = 0
        for (i, item) in storage.enumerated() {
            result.append(item)
            
            sumCost += item.cost()
            let timestamp = item.timeIntervalSince1970
            if i >= limit || sumCost > cost {
                storage.removeFirst(i + 1)
                return result
            }
        }
        
        storage.removeAll()
        return result
    }
}
