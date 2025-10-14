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

//public final class NoOpTransportService: TransportServicing {
//    public var eventQueue = EventQueue()
//    public var batchWorker = BatchWorker(eventQueue: EventQueue())
//
//    public init() {}
//    public func start() {}
//    public func stop() {}
//}

public final class TransportService: TransportServicing {
    public let eventQueue: EventQueue
    public let sessionService: SessionService
    public private(set) var isRunnung: Bool = false
    
    public var batchWorker: BatchWorker
    
    public init(eventQueue: EventQueue, batchWorker: BatchWorker, sessionService: SessionService) {
        self.eventQueue = eventQueue
        self.batchWorker = batchWorker
        self.sessionService = sessionService
    }
    
//    public func add(_ eventSource: EventSource) {
//        eventSources.append(eventSource)
//    }
    
    public func start() {
        guard !isRunnung else { return }
        
        batchWorker.start()
    }
    
    public func stop() {
        guard isRunnung else { return }

//        for eventSource in eventSources {
//            eventSource.stop()
//        }
        batchWorker.stop()
    }
}
