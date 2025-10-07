import MachO

import ApplicationServices

public struct CPULoad {
    private static let machHost = mach_host_self()
    private var loadPrevious = host_cpu_load_info()
    
    public init() {}
    
    private func hostCPULoadInfo() throws -> host_cpu_load_info {
        let hostCpuLoadInfoCount = MemoryLayout<host_cpu_load_info>.stride/MemoryLayout<integer_t>.stride
        var size = mach_msg_type_number_t(hostCpuLoadInfoCount)
        var cpuLoadInfo = host_cpu_load_info()
        
        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: hostCpuLoadInfoCount) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else {
            throw InstrumentationError.failedToReadCpuUsage
        }
        return cpuLoadInfo
    }
    
    /// Get CPU usage (system, user, idle, nice). Determined by the delta between the current and previous invocations.
    public mutating func cpuUsage() throws -> CpuUsage {
        do {
            let load = try hostCPULoadInfo();
            let userDiff: Double = Double(load.cpu_ticks.0 - loadPrevious.cpu_ticks.0);
            let systemDiff = Double(load.cpu_ticks.1 - loadPrevious.cpu_ticks.1);
            let idleDiff = Double(load.cpu_ticks.2 - loadPrevious.cpu_ticks.2);
            let niceDiff = Double(load.cpu_ticks.3 - loadPrevious.cpu_ticks.3);
            
            let totalTicks = userDiff + systemDiff + idleDiff + niceDiff
            let system = systemDiff / totalTicks * 100.0
            let user = userDiff / totalTicks * 100.0
            let idle = idleDiff / totalTicks * 100.0
            let nice = niceDiff / totalTicks * 100.0
            
            loadPrevious = load
            
            return .init(
                user: user,
                system: system,
                idle: idle,
                nice: nice,
                total: totalTicks
            )
        } catch {
            throw error
        }
    }
    
    public func physicalCoresCount() -> UInt {
        var size: size_t = MemoryLayout<UInt>.size
        var coresCount: UInt = 0
        sysctlbyname("hw.physicalcpu", &coresCount, &size, nil, 0)
        return coresCount
    }
}
