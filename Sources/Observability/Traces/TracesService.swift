import Foundation
import Common

public struct TracesService {
    public var recordError: (_ error: Error, _ attributes: [String: AttributeValue]) -> Void
    public var startSpan: (_ name: String, _ attributes: [String: AttributeValue]) -> Span
    public var flush: () async -> Bool
    
    public init(
        recordError: @escaping (_: Error, _: [String : AttributeValue]) -> Void,
        startSpan: @escaping (_: String, _: [String : AttributeValue]) -> Span,
        flush: @escaping () async -> Bool
    ) {
        self.recordError = recordError
        self.startSpan = startSpan
        self.flush = flush
    }
    
    public func recordError(error: Error, attributes: [String: AttributeValue]) {
        recordError(error, attributes)
    }
    
    public func startSpan(name: String, attributes: [String: AttributeValue]) -> Span {
        startSpan(name, attributes)
    }
}
