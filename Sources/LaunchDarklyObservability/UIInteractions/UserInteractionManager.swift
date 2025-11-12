import Common

public final class UserInteractionManager: AutoInstrumentation {
    private var touchCaptureCoordinator: TouchCaptureCoordinator
    private var yields: [TouchInteractionYield]
    
    init(options: Options, yield: @escaping TouchInteractionYield) {
        let targetResolver = TargetResolver()
        self.yields = [yield]
        self.touchCaptureCoordinator = TouchCaptureCoordinator(targetResolver: targetResolver)
        self.touchCaptureCoordinator.yield = { [weak self] interaction in
            self?.yields.forEach { $0(interaction) }
        }
    }
    
    public func addYield(_ yield: @escaping TouchInteractionYield) {
        yields.append(yield)
    }
    
    func start() {
        touchCaptureCoordinator.start()
    }
    
    func stop() {}
}
