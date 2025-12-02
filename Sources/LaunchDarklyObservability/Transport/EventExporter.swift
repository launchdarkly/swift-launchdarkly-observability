import Foundation
#if !LD_COCOAPODS
    import Common
#endif

public protocol EventExporting: Sendable {
    func export(items: [EventQueueItem]) async throws
}

public final class NoOpExporter: EventExporting {
    public func export(items: [EventQueueItem]) async throws { return }
    
    public init() {}
}

extension EventExporting {
    var typeId: ObjectIdentifier {
        ObjectIdentifier(Self.self)
    }
}
