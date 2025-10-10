import Foundation

struct CPUUsage {
    let user: Double
    let system: Double
    let idle: Double
    let nice: Double
}

struct CPUUsageService {

    func getCPUUsage() -> CPUUsage? {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuLoad = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            print("Failed to fetch CPU info. Error code: \(result)")
            return nil
        }

        let user = Double(cpuLoad.cpu_ticks.0)
        let system = Double(cpuLoad.cpu_ticks.1)
        let idle = Double(cpuLoad.cpu_ticks.2)
        let nice = Double(cpuLoad.cpu_ticks.3)

        let total = user + system + idle + nice

        guard total > 0 else {
            return nil
        }

        return CPUUsage(
            user: (user / total) * 100.0,
            system: (system / total) * 100.0,
            idle: (idle / total) * 100.0,
            nice: (nice / total) * 100.0
        )
    }
}
