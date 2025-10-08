import Foundation

class SessionReplayExporter: EventExporting {
    var sessionReplayExporter: ReplayPushService
    var observabilityExporter: ObservabilityExporter
    
    init(sessionReplayExporter: ReplayPushService, observabilityExporter: ObservabilityExporter) {
        self.sessionReplayExporter = sessionReplayExporter
        self.observabilityExporter = observabilityExporter
    }
    
    func export(items: [EventQueueItem]) async throws {
        try await withThrowingTaskGroup { group in
            group.addTask { [self] in
                try await observabilityExporter.export(items: items)
            }
            group.addTask { [self] in
                try await sessionReplayExporter.export(items: items)
            }
            try await group.next()
            try await group.next()
        }
    }
}
