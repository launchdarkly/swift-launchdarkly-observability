import Foundation
import Common

protocol EventExporting {
    func export(items: [EventQueueItem]) async throws
}

final class BatchWorker {
    let eventQueue: EventQueue
    let interval = TimeInterval(2)
    var task: Task<Void, Never>?
    let exporter: EventExporting
    
    init(eventQueue: EventQueue, exporter: EventExporting) {
        self.eventQueue = eventQueue
        self.exporter = exporter
    }
    
    func start() {
        guard task == nil else { return }
        
        task = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            
            while !Task.isCancelled {
                let items = await eventQueue.dequeue(cost: 30000, limit: 20)
                if items.isNotEmpty {
                    await self.send(items: items)
                    continue
                }
                
                try? await Task.sleep(seconds: interval)
            }
        }
    }
    
    func stop() {
        task?.cancel()
    }
    
    func send(items: [EventQueueItem]) async {
        do {
            try await exporter.export(items: items)
        } catch {
            print(error)
        }
    }
}
