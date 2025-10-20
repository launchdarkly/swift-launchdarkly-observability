import Common

final class UserInteractionManager: AutoInstrumentation {
    private var touchCaptureCoordinator: TouchCaptureCoordinator

    init(options: Options, yield: @escaping UIInteractionYield) {
        let targetResolver = TargetResolver()
        self.touchCaptureCoordinator = TouchCaptureCoordinator(targetResolver: targetResolver,
                                                               yield: yield)
    }
    
    func start() {
        touchCaptureCoordinator.start()
    }
}
