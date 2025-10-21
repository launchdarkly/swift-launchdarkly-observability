import Foundation
import Darwin
import OpenTelemetryApi

final class CpuUtilizationManager: AutoInstrumentation {
    private let metricsApi: MetricsApi
    private let options: Options
    private let samplingInterval: TimeInterval
    private var task: Task<Void, Never>?
    
    init(options: Options, metricsApi: MetricsApi, samplingInterval: TimeInterval = 5.0) {
        self.options = options
        self.metricsApi = metricsApi
        self.samplingInterval = samplingInterval
    }
    
    func start() {
        startReporting(interval: samplingInterval)
    }
    
    func startReporting(interval: TimeInterval = 5.0) {
        task = Task { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard let usage = self?.currentCPUUsage() else { continue }
                self?.metricsApi.recordMetric(metric: .init(name: "system.cpu.utilization", value: usage))
            }
        }
    }
    
    func stop() {
        task?.cancel()
        task = nil
    }
    
    func currentCPUUsage() -> Double? {
        var threadList: thread_act_array_t? = nil
        var threadCount: mach_msg_type_number_t = 0
        
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        guard result == KERN_SUCCESS, let threadList = threadList else {
            return nil
        }
        
        defer {
            let size = vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadList)), size)
        }
        
        var totalUsage: Double = 0.0
        
        for i in 0..<threadCount {
            var info = thread_basic_info()
            var count = mach_msg_type_number_t(THREAD_INFO_MAX)
            
            let kr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    thread_info(threadList[Int(i)], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                }
            }
            
            guard kr == KERN_SUCCESS else { continue }
            
            if info.flags & TH_FLAGS_IDLE == 0 {
                let usage = Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                totalUsage += usage
            }
        }
        
        return totalUsage
    }
}
