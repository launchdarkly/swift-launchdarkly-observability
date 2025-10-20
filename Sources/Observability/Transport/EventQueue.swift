import Foundation
import Common

public struct EventQueueItem {
    public var payload: EventQueueItemPayload
    public var cost: Int
    
    public init(payload: EventQueueItemPayload) {
        self.payload = payload
        self.cost = payload.cost()
    }
    
    public var timestamp: TimeInterval {
        payload.timestamp
    }
}

public protocol EventQueuing: Actor {
    func send(_ item: EventQueueItem)
}

// TODO: make it optimal
public actor EventQueue: EventQueuing {
    var storage = [EventQueueItem]()
    var lastEventTime: TimeInterval = 0
    let limitSize: Int
    var currentSize = 0

    public init(limitSize: Int = 5_000_000 /* 5 mb */) {
        self.limitSize = limitSize
    }
    
    public func send(_ item: EventQueueItem) {
        guard currentSize + item.cost <= limitSize else {
            return
        }
        
        storage.append(item)
        lastEventTime = item.timestamp
        currentSize += item.cost
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
            
            sumCost += item.cost
            if i >= limit || sumCost > cost {
                storage.removeFirst(i + 1)
                return result
            }
        }
        
        storage.removeAll()
        return result
    }
}
