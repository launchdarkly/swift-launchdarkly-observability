import Foundation
import Common

public struct EventQueueItem {
    public var payload: EventQueueItemPayload
    public var cost: Int
    public var exporterTypeId: ObjectIdentifier
    
    public init(payload: EventQueueItemPayload) {
        let type = payload.exporterClass
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

public enum EventStatus {
    case oveflowed
    case available
}

public struct EventNotifyStatus {
    public var id: ObjectIdentifier
    public var status: EventStatus
}

struct EventExporterState {
    var size = 0
    var status = EventStatus.available
}

public protocol EventQueuing: Actor {
    func send(_ payload: EventQueueItemPayload) async
}

public actor EventQueue: EventQueuing {
    public struct EarliestItemsResult {
        let id: ObjectIdentifier
        let items: [EventQueueItem]
        let cost: Int
    }

    private var storage = [ObjectIdentifier: [EventQueueItem]]()
    private var lastEventTime: TimeInterval = 0
    private let limitSize: Int
    private var exporterLimitSize: Int
    private var currentSize = 0    
    private var currentSizes = [ObjectIdentifier: EventExporterState]()
    private let broadcaster = Broadcaster<EventNotifyStatus>()
    
    public init(limitSize: Int = 5_000_000 /* 5 mb */, exporterLimitSize: Int = 2_500_000) {
        self.limitSize = limitSize
        self.exporterLimitSize = exporterLimitSize
    }
    
    public func isFull() -> Bool {
        currentSize >= limitSize
    }
    
    public func send(_ payload: EventQueueItemPayload) async {
        send(EventQueueItem(payload: payload))
    }
    
    public func send(_ payloads: [EventQueueItemPayload]) async {
        payloads.forEach {
            send(EventQueueItem(payload: $0))
        }
    }
    
    func send(_ item: EventQueueItem) {
        guard currentSize == 0 || currentSize + item.cost <= limitSize else {
            var exporterState = currentSizes[item.exporterTypeId, default: EventExporterState()]
            notifyOverflowIfNeeded(typeId: item.exporterTypeId, exporterState)
            return
        }
        
        var exporterState = currentSizes[item.exporterTypeId, default: EventExporterState()]
        guard exporterState.size + item.cost <= exporterLimitSize else {
            notifyOverflowIfNeeded(typeId: item.exporterTypeId, exporterState)
            return
        }
        
        storage[item.exporterTypeId, default: []].append(item)
        lastEventTime = item.timestamp
        currentSize += item.cost
        exporterState.size += item.cost
        currentSizes[item.exporterTypeId] = exporterState
    }

    private func notify(typeId: ObjectIdentifier, _ status: EventStatus) {
        Task {
            let notifyStatus = EventNotifyStatus(id: typeId, status: status)
            await broadcaster.send(notifyStatus)
        }
    }
    
    func earliest(cost: Int, limit: Int, except: Set<ObjectIdentifier>) -> EarliestItemsResult? {
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
        
        return EarliestItemsResult(id: earlistEvent.id, items: items, cost: cost)
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
        var exporterState = currentSizes[id, default: EventExporterState()]
        exporterState.size -= removedCost
        
        items.removeFirst(removeCount)
        storage[id] = items.isEmpty ? nil : items
        
        notifyAvailableIfNeeded(typeId: id, exporterState)
    }
    
    public func events() async -> AsyncStream<EventNotifyStatus> {
        await broadcaster.stream()
    }

    private func notifyOverflowIfNeeded(typeId: ObjectIdentifier, _ exporterState: EventExporterState) {
        guard exporterState.status == .available else { return }
        
        var exporterState = exporterState
        exporterState.status = .oveflowed
        currentSizes[typeId] = exporterState
        notify(typeId: typeId, exporterState.status)
    }
    
    private func notifyAvailableIfNeeded(typeId: ObjectIdentifier, _ exporterState: EventExporterState) {
        var exporterState = exporterState
        exporterState.status = .available
        currentSizes[typeId] = exporterState
        
        if exporterState.status == .oveflowed {
            notify(typeId: typeId, exporterState.status)
        }
    }
}
