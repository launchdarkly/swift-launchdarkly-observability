public struct CpuUsage: CustomStringConvertible {
    public let user: Double
    public let system: Double
    public let idle: Double
    public let nice: Double
    
    public var total: Double {
        return user + system + idle + nice
    }
    
    public var description: String {
        "CpuUsage(user: \(user), system: \(system), idle: \(idle), nice: \(nice), total: \(total))"
    }
    
    public init(user: Double, system: Double, idle: Double, nice: Double) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}
