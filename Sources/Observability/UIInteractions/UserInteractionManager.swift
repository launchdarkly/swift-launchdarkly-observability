import Common

public final class UserInteractionManager: AutoInstrumentation {
    private var touchCaptureCoordinator: TouchCaptureCoordinator
    private var yields: [UIInteractionYield]
    
    init(options: Options, yield: @escaping UIInteractionYield) {
        let targetResolver = TargetResolver()
        self.yields = [yield]
        self.touchCaptureCoordinator = TouchCaptureCoordinator(targetResolver: targetResolver)
        self.touchCaptureCoordinator.yield = { [weak self] interaction in
            self?.yields.forEach { $0(interaction) }
        }
    }
    
    public func addYield(_ yield: @escaping UIInteractionYield) {
        yields.append(yield)
    }
    
    func start() {
        touchCaptureCoordinator.start()
    }
    
    func stop() {}
}
