import Foundation
import Common

final class SessionReplayBackroundWorker {
    let eventQueue: EventQueue
    let screenshotManager: ScreenshotManager
    let interval = TimeInterval(2)
    var task: Task<Void, Never>?
    var screenshotService: ScreenshotService
    
    init(screenshotService: ScreenshotService, eventQueue: EventQueue) {
        self.screenshotService = screenshotService
        self.eventQueue = eventQueue
        self.screenshotManager = ScreenshotManager(queue: eventQueue)
    }
    
    func start() {
        guard task == nil else { return }
        screenshotManager.start()
        
        task = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            
            while !Task.isCancelled {
                let items = await eventQueue.dequeue(cost: 30000, count: 20, interval: 30.0)
                if items.isNotEmpty {
                    await self.send(items: items)
                    continue
                }
                
                try? await Task.sleep(seconds: interval)
            }
        }
    }
    
    func stop() {
        task?.cancel()
    }
    
    func send(items: [EventQueueItem]) async {
        do {
            try await screenshotService.send(items: items)
        } catch {
            print(error)
        }
    }
}
