import Foundation

public protocol UIEventSource: AnyObject {
    func start()
    func stop()
}

public protocol UIEventBus: Sendable {
    func publish(_ event: UIInteraction)
}
