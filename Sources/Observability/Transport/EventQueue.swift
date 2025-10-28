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
    func send(_ payload: EventQueueItemPayload) async
}

// TODO: make it optimal
public actor EventQueue: EventQueuing {
    private var storage = [EventQueueItem]()
    private var lastEventTime: TimeInterval = 0
    private let limitSize: Int
    private var currentSize = 0

    public init(limitSize: Int = 5_000_000 /* 5 mb */) {
        self.limitSize = limitSize
    }
    
    public func isFull() -> Bool {
        currentSize >= limitSize
    }
    
    public func send(_ payload: EventQueueItemPayload) async {
        send(EventQueueItem(payload: payload))
    }
    
    func send(_ item: EventQueueItem) {
        guard currentSize + item.cost <= limitSize else {
            return
        }
        
        storage.append(item)
        lastEventTime = item.timestamp
        currentSize += item.cost
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
                currentSize -= item.cost
                storage.removeFirst(i + 1)
                return result
            }
        }
        
        storage.removeAll()
        currentSize = 0
        return result
    }
}
