import Foundation
import Common

public struct EventQueueItem {
    public var payload: EventQueueItemPayload
    public var cost: Int
    public var exporterTypeId: ObjectIdentifier
    
    public init(payload: EventQueueItemPayload) {
        let type = type(of: payload.exporterClass)
        self.init(payload: payload, exporterTypeId: ObjectIdentifier(type))
    }
    
    public init(payload: EventQueueItemPayload, exporterTypeId: ObjectIdentifier) {
        self.payload = payload
        self.cost = payload.cost()
        self.exporterTypeId = exporterTypeId
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
    private var storage = [ObjectIdentifier: [EventQueueItem]]()
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
        
        storage[item.exporterTypeId, default: []].append(item)
        lastEventTime = item.timestamp
        currentSize += item.cost
    }
    
    func earliest(cost: Int, limit: Int, except: Set<ObjectIdentifier>) -> (id: ObjectIdentifier, items: [EventQueueItem], cost: Int)? {
        var earlistEvent: (id: ObjectIdentifier, items: [EventQueueItem], firstTimestamp: TimeInterval)?
        for (id, items) in storage where except.contains(id) == false {
            guard let firstItem = items.first else {
                continue
            }
            if let earlistEventUnwrapped = earlistEvent, firstItem.timestamp >= earlistEventUnwrapped.firstTimestamp {
                continue
            }
            
            earlistEvent = (id, items, firstItem.timestamp)
        }
        
        guard let earlistEvent else { return nil }
        
        guard let (items, cost) = first(cost: cost, limit: limit, items: earlistEvent.items) else {
            return nil
        }
        
        return (id: earlistEvent.id, items: items, cost: cost)
    }
    
    private func first(cost: Int, limit: Int, items: [EventQueueItem]) -> (items: [EventQueueItem], cost: Int)? {
         var sumCost = 0
         var resultItems = [EventQueueItem]()
         for (i, item) in items.enumerated() {
             resultItems.append(item)
             sumCost += item.cost
             
             if i > limit || sumCost > cost {
                 break
             }
         }
         
         return (items: resultItems, sumCost)
    }
    
    func removeFirst(id: ObjectIdentifier, count: Int) {
        guard var items = storage[id], count > 0 else {
            return
        }
        
        let removeCount = min(count, items.count)
        var removedCost = 0
        for i in 0..<removeCount {
            removedCost += items[i].cost
        }
        currentSize -= removedCost
        
        items.removeFirst(removeCount)
        storage[id] = items.isEmpty ? nil : items
    }
}
