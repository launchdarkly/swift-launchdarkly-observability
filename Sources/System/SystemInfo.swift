public struct SystemInfo {
    public var startMonitoring: () -> Void
    public var stopMonitoring: () -> Void
    
    public init(startMonitoring: @escaping () -> Void, stopMonitoring: @escaping () -> Void) {
        self.startMonitoring = startMonitoring
        self.stopMonitoring = stopMonitoring
    }
}
