import Foundation
import Common

public final class BatchWorker {
    let eventQueue: EventQueue
    let interval = TimeInterval(2)
    var task: Task<Void, Never>?
    let multiExporter: MultiEventExporting
    
    public init(eventQueue: EventQueue, multiExporter: MultiEventExporting = MultiEventExporter(exporters: [])) {
        self.eventQueue = eventQueue
        self.multiExporter = multiExporter
    }
    
    public func addExporter(_ exporter: EventExporting) async {
        await multiExporter.addExporter(exporter)
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
        task = nil
    }
    
    func send(items: [EventQueueItem]) async {
        do {
            //try await multiExporter.export(items: items)
        } catch {
            print(error)
        }
    }
}
