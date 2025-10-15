import Foundation

public protocol EventSource: AnyObject {
    func start()
    func stop()
}

public protocol TransportServicing {
    var eventQueue: EventQueue { get }
    var batchWorker: BatchWorker  { get set }
    func start()
    func stop()
}

final class TransportService: TransportServicing {
    public let eventQueue: EventQueue
    public let sessionService: SessionManaging
    public private(set) var isRunnung: Bool = false
    
    public var batchWorker: BatchWorker
    
    public init(eventQueue: EventQueue, batchWorker: BatchWorker, sessionService: SessionManaging) {
        self.eventQueue = eventQueue
        self.batchWorker = batchWorker
        self.sessionService = sessionService
    }
    
    public func start() {
        guard !isRunnung else { return }
        
        batchWorker.start()
    }
    
    public func stop() {
        guard isRunnung else { return }
        batchWorker.stop()
    }
}
