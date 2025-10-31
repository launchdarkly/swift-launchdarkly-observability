import Foundation

public enum MultiExportResult {
    case success
    case partialFailure(groupItems: [ObjectIdentifier: [EventQueueItem]], errors: [ObjectIdentifier: Error])
    case failure
}

public struct TypedIdResult {
    var error: Error?
    var typeId: ObjectIdentifier
    var filteredItems: [EventQueueItem]?
}

public protocol MultiEventExporting {
    func addExporter(_ exporter: EventExporting) async
    func export(groupItems: [ObjectIdentifier: [EventQueueItem]]) async -> MultiExportResult
}

public actor MultiEventExporter: MultiEventExporting {
    var exporters: [ObjectIdentifier: any EventExporting]
    
    public init(exporters initialExporters: [EventExporting]) {
        var exporters = [ObjectIdentifier: any EventExporting]()
        for exporter in initialExporters {
            let exporterId = exporter.typeId
            exporters[exporterId] = exporter
        }
        self.exporters = exporters
    }
    
    public func addExporter(_ exporter: EventExporting) async {
        let exporterId = exporter.typeId
        exporters[exporterId] = exporter
    }
    
    public func export(groupItems: [ObjectIdentifier: [EventQueueItem]]) async -> MultiExportResult {
        let exporters = self.exporters
        
        return await withTaskGroup<TypedIdResult> { group in
            for (typeId, exporter) in exporters {
                group.addTask {
                    guard let filteredItems = groupItems[typeId] else {
                        return TypedIdResult(error: nil, typeId: typeId, filteredItems: nil)
                    }
                    
                    do {
                        try await exporter.export(items: filteredItems)
                        return TypedIdResult(error: nil, typeId: typeId, filteredItems: nil)
                    } catch {
                        return TypedIdResult(error: error, typeId: typeId, filteredItems: filteredItems)
                    }
                }
            }
            
            var failures = [TypedIdResult]()
            var groupItems = [ObjectIdentifier: [EventQueueItem]]()
            var errors = [ObjectIdentifier: Error]()
            
            for _ in 0..<exporters.count {
                do {
                    guard let res = try await group.next() else { break }
                    if let filteredItems = res.filteredItems {
                        groupItems[res.typeId] = res.filteredItems
                        errors[res.typeId] = res.error
                    }
                } catch {
                    
                }
            }
            
            if groupItems.isEmpty {
                return MultiExportResult.success
            } else if failures.count < exporters.count {
                return MultiExportResult.partialFailure(groupItems: groupItems, errors: errors)
            } else {
                return .failure
            }
        }
    }
}


