import UIKit

public protocol UIEventSource: AnyObject {
    func start(yield: @escaping (UIEvent, UIWindow) -> Void)
    func stop()
}

public protocol UIEventBus: Sendable {
    func publish(_ event: TouchInteraction)
}
