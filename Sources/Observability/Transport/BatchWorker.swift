import Foundation
import Common
import OSLog

public final class BatchWorker {
    private let eventQueue: EventQueue
    private let interval = TimeInterval(2)
    private let minInterval = TimeInterval(1)
    private var task: Task<Void, Never>?
    private let multiExporter: MultiEventExporting
    private var log: OSLog
    private var failedItems = [ObjectIdentifier: [EventQueueItem]]()
    
    public init(eventQueue: EventQueue,
                log: OSLog) {
        self.eventQueue = eventQueue
        self.multiExporter = MultiEventExporter(exporters: [], log: log)
        self.log = log
    }
    
    public func addExporter(_ exporter: EventExporting) async {
        await multiExporter.addExporter(exporter)
    }
    
    func start() {
        guard task == nil else { return }
        
        task = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            
            while !Task.isCancelled {
                let sendStart = DispatchTime.now()
                
                if failedItems.isNotEmpty {
                    await sendFailedItems()
                } else {
                    await sendQueueItems()
                }
                
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - sendStart.uptimeNanoseconds) / Double(NSEC_PER_SEC)
                let seconds = max(min(interval - elapsed, interval), minInterval)
                try? await Task.sleep(seconds: seconds)
            }
        }
    }
    
    func sendFailedItems() async {
        let result = await multiExporter.export(groupItems: failedItems)
        switch result {
        case .success:
            failedItems.removeAll()
        case .partialFailure(let results):
            failedItems = results.groupItems
        case .failure:
            break // no-op
        }
    }
    
    func sendQueueItems() async {
        let items = await eventQueue.first(cost: 30000, limit: 20)
        
        guard items.isNotEmpty else {
            try? await Task.sleep(seconds: interval)
            return
        }
        
        let groupItems = [ObjectIdentifier: [EventQueueItem]](grouping: items, by: \.exporterTypeId)
        let result = await multiExporter.export(groupItems: groupItems)
        switch result {
        case .success:
            await eventQueue.removeFirst(items.count)
        case .partialFailure(let results):
            await eventQueue.removeFirst(items.count)
            failedItems = results.groupItems
        case .failure:
            break // no-op
        }
    }
    
    func stop() {
        task?.cancel()
        task = nil
    }
}


