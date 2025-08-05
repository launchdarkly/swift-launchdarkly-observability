public struct SessionOptions: Sendable {
    let timeout: TimeInterval
    let isDebug: Bool

    public init(timeout: TimeInterval = 30 * 60 * 1000, isDebug: Bool = true) {
        self.timeout = timeout
        self.isDebug = isDebug
    }
}
