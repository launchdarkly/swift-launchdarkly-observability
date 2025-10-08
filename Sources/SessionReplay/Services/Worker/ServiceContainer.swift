import Foundation

protocol EventSource: AnyObject {
    func start()
    func stop()
}

final class ServiceContainer {
    let eventSources: [EventSource]
    let batchWorker: BatchWorker
    
    init(eventSources: [EventSource], eventQueue: EventQueue, exporter: EventExporting) {
        self.batchWorker = BatchWorker(eventQueue: eventQueue, exporter: exporter)
        self.eventSources = eventSources
    }
    
    public func start() {
        batchWorker.start()
        for eventSource in eventSources {
            eventSource.start()
        }
    }
    
    public func stop() {
        batchWorker.stop()
        for eventSource in eventSources {
            eventSource.stop()
        }
    }
}

