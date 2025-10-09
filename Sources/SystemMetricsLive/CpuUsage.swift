import MachO
import Darwin

import ApplicationServices

public struct CpuUsageDelta {
    public let user: UInt32
    public let system: UInt32
    public let idle: UInt32
    public let nice: UInt32
    public let total: UInt32
}

public enum CpuUsageDeltaError: Error {
    case statisticsFailed
    case sysctlFailed
}

public struct CpuUsageServiceProvider {
    private var previousTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)? = nil

    public mutating func cpuUsage() throws -> CpuUsageDelta {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { throw CpuUsageDeltaError.statisticsFailed }

        let user = cpuInfo.cpu_ticks.0
        let system = cpuInfo.cpu_ticks.1
        let idle = cpuInfo.cpu_ticks.2
        let nice = cpuInfo.cpu_ticks.3

        let delta: CpuUsageDelta
        if let prev = previousTicks {
            let dUser = user &- prev.user
            let dSystem = system &- prev.system
            let dIdle = idle &- prev.idle
            let dNice = nice &- prev.nice
            let dTotal = dUser &+ dSystem &+ dIdle &+ dNice
            delta = CpuUsageDelta(user: dUser, system: dSystem, idle: dIdle, nice: dNice, total: dTotal)
        } else {
            delta = CpuUsageDelta(user: 0, system: 0, idle: 0, nice: 0, total: 0)
        }
        previousTicks = (user: user, system: system, idle: idle, nice: nice)
        return delta
    }
    
    func physicalCoreCount() throws -> Int {
        var count: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("hw.physicalcpu", &count, &size, nil, 0)
        guard result == 0 else { throw CpuUsageDeltaError.sysctlFailed }
        
        return Int(count)
    }
}
