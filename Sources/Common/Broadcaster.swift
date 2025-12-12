import Foundation

public actor Broadcaster<Value: Sendable> {
    private var continuations = [Int: AsyncStream<Value>.Continuation]()
    private var streamIdentifier = 0
    private var finished = false
    
    public init() { }
    
    deinit {
        finished = true
        
        // Disable termination handlers so finish() is "silent"
        for c in continuations.values {
            c.onTermination = nil
            c.finish()
        }
        continuations.removeAll()
    }
    
    public func stream(
        bufferingPolicy: AsyncStream<Value>.Continuation.BufferingPolicy = .unbounded
    ) -> AsyncStream<Value> {
        let id = streamIdentifier
        streamIdentifier &+= 1
        
        let stream = AsyncStream<Value>(bufferingPolicy: bufferingPolicy) { continuation in
            if finished {
                continuation.finish()
                return
            }
            
            self.continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { [weak self] in
                    guard let self else { return }
                    await self.removeContinuation(id: id)
                }
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


