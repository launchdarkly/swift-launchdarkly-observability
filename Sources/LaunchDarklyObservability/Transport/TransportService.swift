import Foundation
import Combine

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
    public let sessionManager: SessionManaging
    public private(set) var isRunnung: Bool = false
    public var batchWorker: BatchWorker
    private let appLifecycleManager: AppLifecycleManaging
    private var cancellables = Set<AnyCancellable>()

    public init(eventQueue: EventQueue,
                batchWorker: BatchWorker,
                sessionManager: SessionManaging,
                appLifecycleManager: AppLifecycleManaging) {
        self.eventQueue = eventQueue
        self.batchWorker = batchWorker
        self.sessionManager = sessionManager
        self.appLifecycleManager = appLifecycleManager
        
        
        appLifecycleManager
            .publisher()
            .receive(on: DispatchQueue.global())
            .sink { [weak self] event in
                if event == .willResignActive {
                    Task { [weak self] in
                        await self?.batchWorker.flush()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    public func start() {
        guard !isRunnung else { return }
        Task {
            await batchWorker.start()
        }
    }
    
    public func stop() {
        guard isRunnung else { return }
        Task {
            await batchWorker.stop()
        }
    }
}
