import Common
import ApplicationServices
import DomainModels

extension UserInteractionService {
    public static func build(
        tracesService: TracesService,
        eventQueue: EventQueuing,
    ) -> Self {
        
        let tapHandler = TapHandler()
        let swipeHandler = SwipeHandler()
        
        return UserInteractionService(
            start: {
                UIWindowSendEvent.inject { uiWindow, uiEvent in
                    
                    tapHandler.handle(event: uiEvent, window: uiWindow) { touchEvent in
                        Task {
                            await eventQueue.send(EventQueueItem(payload: TouchItemPayload(touchEvent: touchEvent)))
                        }
                        
                        var attributes = [String: AttributeValue]()
                        let viewName = touchEvent.viewName ?? "unknown"
                        attributes["screen.name"] = .string(viewName)
                        attributes["target.id"] = .string(touchEvent.accessibilityIdentifier ?? viewName)
                        // sending location in points (since it is preferred over pixels)
                        attributes["position.x"] = .string(touchEvent.locationInPoints.x.toString())
                        attributes["position.y"] = .string(touchEvent.locationInPoints.y.toString())
                        tracesService.startSpan(name: "user.tap", attributes: attributes).end()
                    }
                    
                    swipeHandler.handle(event: uiEvent, window: uiWindow) { touchEvent in
                        let viewName = touchEvent.viewName ?? "unknown"
                        var attributes = [String: AttributeValue]()
                        attributes["screen.name"] = .string(viewName)
                        attributes["target.id"] = .string(touchEvent.accessibilityIdentifier ?? viewName)
                        // sending location in points (since it is preferred over pixels)
                        attributes["position.x"] = .string(touchEvent.locationInPoints.x.toString())
                        attributes["position.y"] = .string(touchEvent.locationInPoints.y.toString())
                        tracesService.startSpan(name: "user.swipe", attributes: attributes).end()
                    }
                }
            }
        )
    }
}
