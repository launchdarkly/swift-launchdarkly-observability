import Combine

#if !LD_COCOAPODS
    import Common
#endif

public final class UserInteractionManager {
    private var touchCaptureCoordinator: TouchCaptureCoordinator
    private let subject = PassthroughSubject<TouchInteraction, Never>()
    
    public var publisher: AnyPublisher<TouchInteraction, Never> {
        subject.eraseToAnyPublisher()
    }
    
    init(options: Options, yield: @escaping TouchInteractionYield) {
        let targetResolver = TargetResolver()
        self.touchCaptureCoordinator = TouchCaptureCoordinator(targetResolver: targetResolver)
        self.touchCaptureCoordinator.yield = { [subject] interaction in
            yield(interaction)
            subject.send(interaction)
        }
    }
    
    init(options: Options) {
        let targetResolver = TargetResolver()
        self.touchCaptureCoordinator = TouchCaptureCoordinator(targetResolver: targetResolver)        
    }
    
    func setYield(_ yield: TouchInteractionYield?) {
        guard let yield else {
            return self.touchCaptureCoordinator.yield = nil
        }
        self.touchCaptureCoordinator.yield = { [subject] interaction in
        yield(interaction)
        subject.send(interaction)
    }
    }
        
    func start() {
        touchCaptureCoordinator.start()
    }
    
    func stop() {
    }
}
