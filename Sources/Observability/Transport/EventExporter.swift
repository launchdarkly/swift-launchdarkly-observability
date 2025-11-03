import Foundation
import Common

public protocol EventExporting: Sendable {
    func export(items: [EventQueueItem]) async throws
}

public final class NoOpExporter: EventExporting {
    public func export(items: [EventQueueItem]) async throws { return }
    
    public init() {}
}

extension EventExporting {
    var typeId: ObjectIdentifier {
        let type = type(of: Self.self)
        return ObjectIdentifier(type)
    }
}
