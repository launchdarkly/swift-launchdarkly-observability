import Common
import ApplicationServices

extension UserInteractionService {
    public static func build(
        tracesService: TracesService
    ) -> Self {
        
        let tapHandler = TapHandler()
        let swipeHandler = SwipeHandler()
        
        
        return .init(
            start: {
                UIWindowSendEvent.inject { uiWindow, uiEvent in
                    tapHandler.handle(event: uiEvent, window: uiWindow) { touchEvent in
                        var attributes = [String: AttributeValue]()
                        attributes["screen.name"] = .string(touchEvent.viewName)
                        attributes["target.id"] = .string(touchEvent.accessibilityIdentifier ?? touchEvent.viewName)
                        // sending location in points (since it is preferred over pixels)
                        attributes["position.x"] = .string(touchEvent.locationInPoints.x.toString())
                        attributes["position.y"] = .string(touchEvent.locationInPoints.y.toString())
                        tracesService.startSpan(name: "user.tap", attributes: attributes).end()
                    }
                    swipeHandler.handle(event: uiEvent, window: uiWindow) { touchEvent in
                        var attributes = [String: AttributeValue]()
                        attributes["screen.name"] = .string(touchEvent.viewName)
                        attributes["target.id"] = .string(touchEvent.accessibilityIdentifier ?? touchEvent.viewName)
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
