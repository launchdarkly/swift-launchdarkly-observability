import Foundation

/// An interface that represents a span. It has an associated SpanContext.
/// Spans are created by the SpanBuilder.startSpan method.
/// Span must be ended by calling end().
public struct Span {
    /// End the span.
    public var end: (_ time: Date) -> Void
    
    public init(
        end: @escaping (_: Date) -> Void
    ) {
        self.end = end
    }
    
    public func end(time: Date = .init()) {
        end(time)
    }
}
