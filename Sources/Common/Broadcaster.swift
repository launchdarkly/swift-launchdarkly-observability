import Foundation

public actor Broadcaster<Value: Sendable> {
    private var continuations = [Int: AsyncStream<Value>.Continuation]()
    private var nextIdentifier = 0
    private var finished = false
    
    public init() { }
    
    public func stream(
        bufferingPolicy: AsyncStream<Value>.Continuation.BufferingPolicy = .unbounded
    ) -> AsyncStream<Value> {
        let id = nextIdentifier
        nextIdentifier &+= 1
        var continuationRef: AsyncStream<Value>.Continuation?
        
        let stream = AsyncStream<Value>(bufferingPolicy: bufferingPolicy) { continuation in
            continuationRef = continuation
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.removeContinuation(id: id) }
            }
        }
        
        if let continuation = continuationRef {
            if finished {
                continuation.finish()
            } else {
                continuations[id] = continuation
            }
        }
        
        return stream
    }
    
    public func send(_ event: Value) {
        guard !finished else { return }
        for continuation in continuations.values {
            _ = continuation.yield(event)
        }
    }
    
    public func finish() {
        guard !finished else { return }
        finished = true
        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
    }
    
    private func removeContinuation(id: Int) {
        continuations.removeValue(forKey: id)
    }
}


