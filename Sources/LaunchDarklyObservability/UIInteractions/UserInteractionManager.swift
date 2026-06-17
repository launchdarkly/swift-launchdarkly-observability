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
    
    /// Resolves the active screen (`event.screen_id` / `event.screen_name`) at the instant of a tap.
    public typealias ScreenInfoProvider = @Sendable () -> (screenId: String?, screenName: String?)

    init(
        options: ObservabilityOptions,
        sessionManaging: SessionManaging,
        screenInfoProvider: @escaping ScreenInfoProvider = { (nil, nil) },
        yield: @escaping TouchInteractionYield
    ) {
        let targetResolver = TargetResolver()
        self.inputCaptureCoordinator = InputCaptureCoordinator(
            targetResolver: targetResolver,
            sessionIdProvider: sessionManaging.sessionIdProvider
        )
        self.inputCaptureCoordinator.onTouch = { [interactionEventSubject] interaction in
            // Stamp the live screen once, here in the single funnel both consumers read, so the OTel
            // `click` span and the Session Replay click event always agree on the screen.
            var interaction = interaction
            let screen = screenInfoProvider()
            interaction.screenId = screen.screenId
            interaction.screenName = screen.screenName
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
