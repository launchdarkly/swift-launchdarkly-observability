import Foundation
import Common

/// An interface that represents a span. It has an associated SpanContext.
/// Spans are created by the SpanBuilder.startSpan method.
/// Span must be ended by calling end().
public struct Span {
    /// End the span.
    public var end: (_ time: Date) -> Void
    public var addEvent: (_ name: String, _ attributes: [String: AttributeValue], _ timestamp: Date) -> Void
    
    public init(
        end: @escaping (_: Date) -> Void,
        addEvent: @escaping (_: String, _: [String : AttributeValue], _: Date) -> Void
    ) {
        self.end = end
        self.addEvent = addEvent
    }
    
    public func end(time: Date = .init()) {
        end(time)
    }
    
    public func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {
        addEvent(name, attributes, timestamp)
    }
}
