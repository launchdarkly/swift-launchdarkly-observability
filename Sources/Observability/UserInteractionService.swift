public struct UserInteractionService {
    public var start: () -> Void
    
    public init(start: @escaping () -> Void) {
        self.start = start
    }
}
