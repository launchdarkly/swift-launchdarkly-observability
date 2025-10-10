import Foundation
import Darwin

public struct LogicalCPUUtilization {
    public enum Mode {
        case user, system, idle, nice
    }
    public let cpuIndex: Int
    public let utilization: Double // 0.0 ... 1.0
    public let byMode: [Mode: Double]
}

public enum SystemCPUUtilizationError: Error {
    case processorInfoFailed
    case noPreviousSnapshot
    case timeError
}

public final class SystemCPUUtilizationService {
    private var previousTimes: [[UInt32]]? = nil // [[user, system, idle, nice]] per CPU
    private var previousTimestamp: TimeInterval? = nil
    private let lock = NSLock()
    
    public init() {}
    
    /// Take a snapshot of current per-CPU times
    public func snapshot() throws {
        let (cpuTimes, _) = try Self.getCPUTimes()
        lock.lock()
        previousTimes = cpuTimes
        previousTimestamp = Date().timeIntervalSince1970
        lock.unlock()
    }
    
    // Measure utilization since last snapshot
    public func utilizationSinceLastSnapshot() throws -> [LogicalCPUUtilization] {
        lock.lock()
        defer { lock.unlock() }
        guard let prevTimes = previousTimes, let prevTimestamp = previousTimestamp else {
            throw SystemCPUUtilizationError.noPreviousSnapshot
        }
        let (currTimes, cpuCount) = try Self.getCPUTimes()
        let currTimestamp = Date().timeIntervalSince1970
        let elapsed = currTimestamp - prevTimestamp
        guard elapsed > 0 else { throw SystemCPUUtilizationError.timeError }
        var results: [LogicalCPUUtilization] = []
        for i in 0..<cpuCount {
            let prev = prevTimes[i]
            let curr = currTimes[i]
            let deltaUser = Double(curr[0] &- prev[0])
            let deltaSystem = Double(curr[1] &- prev[1])
            let deltaIdle = Double(curr[2] &- prev[2])
            let deltaNice = Double(curr[3] &- prev[3])
            let deltaTotal = deltaUser + deltaSystem + deltaIdle + deltaNice
            let deltaActive = deltaUser + deltaSystem + deltaNice
            let utilization = deltaTotal > 0 ? deltaActive / deltaTotal : 0.0
            
            results.append(LogicalCPUUtilization(
                cpuIndex: i,
                utilization: utilization,
                byMode: [
                    .user: deltaTotal > 0 ? deltaUser / deltaTotal : 0.0,
                    .system: deltaTotal > 0 ? deltaSystem / deltaTotal : 0.0,
                    .idle: deltaTotal > 0 ? deltaIdle / deltaTotal : 0.0,
                    .nice: deltaTotal > 0 ? deltaNice / deltaTotal : 0.0
                ]
            )
            )
        }
        // Update snapshot for next measurement
        previousTimes = currTimes
        previousTimestamp = currTimestamp
        return results
    }
    
    // Helper to get per-CPU times
    private static func getCPUTimes() throws -> ([[UInt32]], Int) {
        var cpuInfo: processor_info_array_t? = nil
        var cpuInfoCount: mach_msg_type_number_t = 0
        var cpuCount: natural_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &cpuInfo, &cpuInfoCount)
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            throw SystemCPUUtilizationError.processorInfoFailed
        }
        var times: [[UInt32]] = []
        for i in 0..<Int(cpuCount) {
            let base = Int(CPU_STATE_MAX) * i
            let user = UInt32(cpuInfo[base + Int(CPU_STATE_USER)])
            let system = UInt32(cpuInfo[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt32(cpuInfo[base + Int(CPU_STATE_IDLE)])
            let nice = UInt32(cpuInfo[base + Int(CPU_STATE_NICE)])
            times.append([user, system, idle, nice])
        }
        // Deallocate
        let cpuInfoSize = Int(cpuInfoCount) * MemoryLayout<integer_t>.size
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(cpuInfoSize))
        return (times, Int(cpuCount))
    }
}
