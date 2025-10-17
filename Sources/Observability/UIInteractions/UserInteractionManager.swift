import Common

final class UserInteractionManager: AutoInstrumentation {
    private let userInteractions: UserInteractions
    
    init(tracesApi: TracesApi, eventQueue: EventQueuing) {
        self.userInteractions = UserInteractions(tracesApi: tracesApi, eventQueue: eventQueue)
        self.userInteractions.start()
    }
}

fileprivate final class UserInteractions {
    private let tapHandler = TapHandler()
    private let swipeHandler = SwipeHandler()
    private let tracesApi: TracesApi
    private let eventQueue: EventQueuing
    
    init(tracesApi: TracesApi, eventQueue: EventQueuing) {
        self.tracesApi = tracesApi
        self.eventQueue = eventQueue
    }
    
    func start() {
        UIWindowSwizzleSource.inject { [weak self] uiWindow, uiEvent in
            self?.tapHandler.handle(event: uiEvent, window: uiWindow) { touchEvent in
                Task {
                    await self?.eventQueue.send(EventQueueItem(payload: TouchItemPayload(touchEvent: touchEvent)))
                }
                var attributes = [String: AttributeValue]()
                let viewName = touchEvent.viewName ?? "unknown"
                attributes["screen.name"] = .string(viewName)
                attributes["target.id"] = .string(touchEvent.accessibilityIdentifier ?? viewName)
                // sending location in points (since it is preferred over pixels)
                attributes["position.x"] = .string(touchEvent.locationInPoints.x.toString())
                attributes["position.y"] = .string(touchEvent.locationInPoints.y.toString())
                self?.tracesApi.startSpan(name: "user.tap", attributes: attributes).end()
            }
            self?.swipeHandler.handle(event: uiEvent, window: uiWindow) { touchEvent in
                let viewName = touchEvent.viewName ?? "unknown"
                var attributes = [String: AttributeValue]()
                attributes["screen.name"] = .string(viewName)
                attributes["target.id"] = .string(touchEvent.accessibilityIdentifier ?? viewName)
                // sending location in points (since it is preferred over pixels)
                attributes["position.x"] = .string(touchEvent.locationInPoints.x.toString())
                attributes["position.y"] = .string(touchEvent.locationInPoints.y.toString())
                self?.tracesApi.startSpan(name: "user.swipe", attributes: attributes).end()
            }
        }
    }
    

}
