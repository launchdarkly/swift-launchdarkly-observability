#if !LD_COCOAPODS
    import Common
#endif

public final actor UserInteractionManager {
    private var touchCaptureCoordinator: TouchCaptureCoordinator
    private var yields: [TouchInteractionYield]
    
    init(options: Options, yield: @escaping TouchInteractionYield) {
        let targetResolver = TargetResolver()
        self.yields = [yield]
        self.touchCaptureCoordinator = TouchCaptureCoordinator(targetResolver: targetResolver)
        self.setYields(yields)
    }
    
    public func addYield(_ yield: @escaping TouchInteractionYield) {
        setYields(self.yields + [yield])
    }
    
    private func setYields(_ yields: [TouchInteractionYield]) {
        self.touchCaptureCoordinator.yield = { [weak self] interaction in
            yields.forEach { $0(interaction) }
        }
        self.yields = yields
    }
    
    func start() {
        touchCaptureCoordinator.start()
    }
    
    func stop() {}
}
