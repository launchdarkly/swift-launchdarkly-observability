public struct CpuUsage {
    public let user: Double
    public let system: Double
    public let idle: Double
    public let nice: Double
    public let total: Double
    
    public init(user: Double, system: Double, idle: Double, nice: Double, total: Double) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
        self.total = total
    }
}
