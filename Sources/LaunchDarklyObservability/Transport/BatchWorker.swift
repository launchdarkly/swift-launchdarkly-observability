import Foundation
import Common
import OSLog

public final actor BatchWorker {
    enum Constants {
        static let maxConcurrentCost: Int = 30000
        static let maxConcurrentItems: Int = 100
        static let maxConcurrentExporters: Int = 2
        static let baseBackoffSeconds: TimeInterval = 2
        static let maxBackoffSeconds: TimeInterval = 60
        static let backoffJitter: Double = 0.2
    }
    
    private struct BackOffExporterInfo {
        var until: DispatchTime
        var attempts: Int
    }
    
    private let eventQueue: EventQueue
    private let interval = TimeInterval(4)
    private let minInterval = TimeInterval(1.5)
    private var task: Task<Void, Never>?
    private var log: OSLog
    private var exporters = [ObjectIdentifier: any EventExporting]()
    private var costInFlight = 0
    private var exportersInFlight = Set<ObjectIdentifier>()
    private var exporterBackoff = [ObjectIdentifier: BackOffExporterInfo]()

    public init(eventQueue: EventQueue,
                log: OSLog) {
        self.eventQueue = eventQueue
        self.log = log
    }
    
    public func addExporter(_ exporter: EventExporting) async {
        let exporterId = exporter.typeId
        exporters[exporterId] = exporter
    }
    
    public func start() {
        guard task == nil else { return }
        
        task = Task.detached(priority: .background) { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let scheduledCost = await sendQueueItems()
                try? await Task.sleep(seconds: scheduledCost > 0 ? minInterval : interval)
            }
        }
    }
    
    func sendQueueItems() async -> Int {
        var scheduledCost = 0
        
        while true {
            let remainingExporterSlots = Constants.maxConcurrentExporters - exportersInFlight.count
            guard remainingExporterSlots > 0 else { break }
            
            let budget = Constants.maxConcurrentCost - costInFlight
            guard costInFlight == 0 || budget > 0 else { break }

            let now = DispatchTime.now()
            var except = exportersInFlight
            for (id, info) in exporterBackoff where info.until > now {
                except.insert(id)
            }

            guard let earliest = await eventQueue.earliest(cost: budget,
                                                           limit: Constants.maxConcurrentItems,
                                                           except: except) else {
                break
            }
            let exporterId = earliest.id
            let items = earliest.items
            let cost = earliest.cost
            
            guard let exporter = exporters[exporterId] else {
                os_log("%{public}@", log: log, type: .error, "Dropping \(items.count) items: exporter not found for id \(exporterId)")
                await eventQueue.removeFirst(id: exporterId, count: items.count)
                continue
            }
            
            if tryReserve(exporterId: exporterId, cost: cost) {
                Task.detached(priority: .background) { [weak self] in
                    do {
                        try await exporter.export(items: items)
                        await self?.finishExport(exporterId: exporterId, itemsCount: items.count, cost: cost, error: nil)
                    } catch {
                        await self?.finishExport(exporterId: exporterId, itemsCount: items.count, cost: cost, error: error)
                    }
                }
                scheduledCost += cost
            }
        }
        
        return scheduledCost
    }
    
    private func tryReserve(exporterId: ObjectIdentifier, cost: Int) -> Bool {
        guard exportersInFlight.contains(exporterId) == false else {
            return false
        }
        
        exportersInFlight.insert(exporterId)
        costInFlight += cost
        return true
    }
    
    private func finishExport(exporterId: ObjectIdentifier, itemsCount: Int, cost: Int, error: Error?) async {
        if let error {
            os_log("%{public}@", log: log, type: .error, "Exporter \(exporterId) failed with error \(error)")
            let attempts = (exporterBackoff[exporterId]?.attempts ?? 0) + 1
            let backoff = min(Constants.baseBackoffSeconds * pow(2, Double(max(0, attempts - 1))), Constants.maxBackoffSeconds)
            let jitter = backoff * Constants.backoffJitter
            let jittered = max(0, backoff + Double.random(in: -jitter...jitter))
            let until = DispatchTime.now() + .milliseconds(Int(jittered * 1000))
            exporterBackoff[exporterId] = BackOffExporterInfo(until: until, attempts: attempts)
        } else {
            await eventQueue.removeFirst(id: exporterId, count: itemsCount)
            exporterBackoff[exporterId] = nil
        }
        
        exportersInFlight.remove(exporterId)
        costInFlight -= cost
    }
    
    public func stop() {
        task?.cancel()
        task = nil
    }
}
