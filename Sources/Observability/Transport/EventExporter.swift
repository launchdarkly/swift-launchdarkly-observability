import Foundation
import Common

public protocol EventExporting {
    func export(items: [EventQueueItem]) async throws
}

public final class NoOpExporter: EventExporting {
    public func export(items: [EventQueueItem]) async throws {}
    
    public init() {}
}
