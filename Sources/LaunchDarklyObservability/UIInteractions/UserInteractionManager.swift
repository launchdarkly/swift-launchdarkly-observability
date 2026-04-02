import Combine

#if !LD_COCOAPODS
    import Common
#endif

public final class UserInteractionManager {
    private var inputCaptureCoordinator: InputCaptureCoordinator
    private let subject = PassthroughSubject<TouchInteraction, Never>()
    
    public var publisher: AnyPublisher<TouchInteraction, Never> {
        subject.eraseToAnyPublisher()
    }
    
    init(options: Options, yield: @escaping TouchInteractionYield) {
        let targetResolver = TargetResolver()
        self.inputCaptureCoordinator = InputCaptureCoordinator(targetResolver: targetResolver)
        self.inputCaptureCoordinator.onTouch = { [subject] interaction in
            yield(interaction)
            subject.send(interaction)
        }
    }
        
    func start() {
        inputCaptureCoordinator.start()
    }
    
    func stop() {
    }
}
