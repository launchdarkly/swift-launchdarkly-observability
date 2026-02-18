import Foundation
import Combine

public protocol EventSource: AnyObject {
}

public protocol TransportingService {
    func start() async
    func stop() async
}

public protocol TransportServicing {
    var eventQueue: EventQueue { get }
    var batchWorker: BatchWorker  { get set }
    func start()
    func stop()
}

final class TransportService: TransportServicing, TransportingService {
    public let eventQueue: EventQueue
    private let sessionManager: SessionManaging
    private var isRunning: Bool = false
    public var batchWorker: BatchWorker
    private let appLifecycleManager: AppLifecycleManaging
    private var cancellables = Set<AnyCancellable>()
    
    init(eventQueue: EventQueue,
         batchWorker: BatchWorker,
         sessionManager: SessionManaging,
         appLifecycleManager: AppLifecycleManaging) {
        self.eventQueue = eventQueue
        self.batchWorker = batchWorker
        self.sessionManager = sessionManager
        self.appLifecycleManager = appLifecycleManager
        
        
        appLifecycleManager
            .publisher()
            .receive(on: DispatchQueue.global(qos: .background))
            .sink { [weak self] event in
                if event == .willResignActive || event == .willTerminate {
                    Task { [weak self] in
                        await self?.batchWorker.flush()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    public func start() {
        guard !isRunning else { return }
        Task {
            await batchWorker.start()
        }
    }
    
    public func stop() {
        guard isRunning else { return }
        Task {
            await batchWorker.stop()
        }
    }
}
