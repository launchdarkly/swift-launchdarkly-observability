import Foundation
import Combine

#if !LD_COCOAPODS
    import Common
#endif

public final class UserInteractionManager {
    private var inputCaptureCoordinator: InputCaptureCoordinator
    private let interactionEventSubject = PassthroughSubject<InteractionEvent, Never>()
    private let startLock = NSLock()
    private var isStarted = false
    
    /// Ordered stream of touches (``TouchInteraction``) and non-spatial ``PressInteraction``.
    public var interactionEvents: AnyPublisher<InteractionEvent, Never> {
        interactionEventSubject.eraseToAnyPublisher()
    }
    
    init(options: ObservabilityOptions, sessionManaging: SessionManaging, yield: @escaping TouchInteractionYield) {
        let targetResolver = TargetResolver()
        self.inputCaptureCoordinator = InputCaptureCoordinator(
            targetResolver: targetResolver,
            sessionIdProvider: sessionManaging.sessionIdProvider
        )
        self.inputCaptureCoordinator.onTouch = { [interactionEventSubject] interaction in
            yield(interaction)
            interactionEventSubject.send(.touch(interaction))
        }
        self.inputCaptureCoordinator.onPress = { [interactionEventSubject] pressInteraction in
            interactionEventSubject.send(.press(pressInteraction))
        }
    }
        
    /// Installs the touch-capture hook (swizzles `UIWindow.sendEvent`). Idempotent and
    /// thread-safe, so it can be called by both the Observability tap instrumentation (gated
    /// by ``ObservabilityOptions/Instrumentation/userTaps``) and by Session Replay, whichever
    /// activates first. When neither needs it the hook is never installed.
    public func start() {
        startLock.lock()
        let shouldStart = !isStarted
        isStarted = true
        startLock.unlock()
        guard shouldStart else { return }
        inputCaptureCoordinator.start()
    }
    
    func stop() {
    }
}
