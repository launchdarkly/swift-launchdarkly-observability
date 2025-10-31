import Foundation
import Common

//public struct ExportResult: Error {
//    var indexes: [Int]
//    var cause: Error
//    
//    public init(indexes: [Int], cause: Error) {
//        self.indexes = indexes
//        self.cause = cause
//    }
//}

public protocol EventExporting {
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
