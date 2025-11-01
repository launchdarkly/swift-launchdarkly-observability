import Foundation
import OSLog

public enum MultiExportResult {
    case success
    case partialFailure(groupItems: [ObjectIdentifier: [EventQueueItem]], errors: [ObjectIdentifier: Error])
    case failure
}

public struct TypeIdError: Error {
    public let typeId: ObjectIdentifier
    public let underlyingError: Error
    public let filteredItems: [EventQueueItem]
}

typealias TypedIdResult = Result<Void, TypeIdError>

public protocol MultiEventExporting {
    func addExporter(_ exporter: EventExporting) async
    func export(groupItems: [ObjectIdentifier: [EventQueueItem]]) async -> MultiExportResult
}

public actor MultiEventExporter: MultiEventExporting {
    var exporters: [ObjectIdentifier: any EventExporting]
    let log: OSLog
    
    public init(exporters initialExporters: [EventExporting], log: OSLog) {
        var exporters = [ObjectIdentifier: any EventExporting]()
        for exporter in initialExporters {
            let exporterId = exporter.typeId
            exporters[exporterId] = exporter
        }
        self.exporters = exporters
        self.log = log
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
                        return TypedIdResult.success(())
                    }
                    
                    do {
                        try await exporter.export(items: filteredItems)
                        return TypedIdResult.success(())
                    } catch {
                        let typeIdError = TypeIdError(typeId: typeId, underlyingError: error, filteredItems: filteredItems)
                        return TypedIdResult.failure(typeIdError)
                    }
                }
            }
            
            var groupItems = [ObjectIdentifier: [EventQueueItem]]()
            var errors = [ObjectIdentifier: Error]()
            
            for _ in 0..<exporters.count {
                do {
                    guard let typedIdResult = try await group.next() else { break }
                    if case .failure(let error) = typedIdResult {
                        groupItems[error.typeId] = error.filteredItems
                        errors[error.typeId] = error.underlyingError
                    }
                } catch {
                    os_log("%{public}@", log: log, type: .error, "MultiEventExporter group.next(: \(error)")
                }
            }
            
            if errors.isEmpty {
                return MultiExportResult.success
            } else if errors.count < exporters.count {
                return MultiExportResult.partialFailure(groupItems: groupItems, errors: errors)
            } else {
                return .failure
            }
        }
    }
}


