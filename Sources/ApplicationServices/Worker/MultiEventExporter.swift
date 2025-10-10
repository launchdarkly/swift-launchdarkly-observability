import Foundation
import ApplicationServices

public protocol MultiEventExporting: EventExporting {
    func addExporter(_ exporter: EventExporting) async
}

public actor MultiEventExporter: MultiEventExporting {
    var exporters: [EventExporting]
    
    public init(exporters: [EventExporting]) {
        self.exporters = exporters
    }
    
    public func addExporter(_ exporter: EventExporting) async {
        exporters.append(exporter)
    }
    
    public func export(items: [EventQueueItem]) async throws {
        let exporters = self.exporters
        try await withThrowingTaskGroup { group in
            for exporter in exporters {
                group.addTask {
                    try await exporter.export(items: items)
                }
            }
            
            for _ in exporters {
                try await group.next()
            }
        }
    }
}
