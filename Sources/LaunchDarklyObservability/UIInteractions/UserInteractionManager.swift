import Combine

#if !LD_COCOAPODS
    import Common
#endif

public final class UserInteractionManager {
    private var inputCaptureCoordinator: InputCaptureCoordinator
    private let interactionEventSubject = PassthroughSubject<InteractionEvent, Never>()
    
    /// Ordered stream of touches (``TouchInteraction``) and non-spatial ``PressInteraction``.
    public var interactionEvents: AnyPublisher<InteractionEvent, Never> {
        interactionEventSubject.eraseToAnyPublisher()
    }
    
    init(options: ObservabilityOptions, sessionManaging: SessionManaging, yield: @escaping TouchInteractionYield) {
        let targetResolver = TargetResolver()
        self.inputCaptureCoordinator = InputCaptureCoordinator(
            targetResolver: targetResolver,
            sessionIdProvider: { sessionManaging.sessionInfo.id }
        )
        self.inputCaptureCoordinator.onTouch = { [interactionEventSubject] interaction in
            yield(interaction)
            interactionEventSubject.send(.touch(interaction))
        }
        self.inputCaptureCoordinator.onPress = { [interactionEventSubject] pressInteraction in
            interactionEventSubject.send(.press(pressInteraction))
        }
    }
        
    func start() {
        inputCaptureCoordinator.start()
    }
    
    func stop() {
    }
}
