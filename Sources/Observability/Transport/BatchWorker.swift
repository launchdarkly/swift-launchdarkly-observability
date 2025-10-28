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
    
    public init(eventQueue: EventQueue,
                log: OSLog,
                multiExporter: MultiEventExporting = MultiEventExporter(exporters: [])) {
        self.eventQueue = eventQueue
        self.multiExporter = multiExporter
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
                let items = await eventQueue.dequeue(cost: 30000, limit: 20)
              
                guard items.isNotEmpty else {
                    try? await Task.sleep(seconds: interval)
                    continue
                }
                
                let sendStart = DispatchTime.now()
                await self.send(items: items)
                
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - sendStart.uptimeNanoseconds) / Double(NSEC_PER_SEC)
                let seconds = max(interval - elapsed, minInterval)
                try? await Task.sleep(seconds: seconds)
            }
        }
    }
    
    func stop() {
        task?.cancel()
        task = nil
    }
    
    func send(items: [EventQueueItem]) async {
        do {
            try await multiExporter.export(items: items)
        } catch {
            os_log("%{public}@", log: log, type: .error, "BatchWorked has failed to send items: \(error)")
        }
    }
}
