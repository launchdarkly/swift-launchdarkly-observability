import Foundation
import OSLog
import Darwin

struct MemoryUseManager {
    static func memoryReport(log: OSLog) -> MemoryReport? {
        // --- SYSTEM MEMORY STATS ---
        var stats = vm_statistics64()
        let HOST_VM_INFO64_COUNT = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var count = HOST_VM_INFO64_COUNT
        
        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            os_log("%{public}@", log: log, type: .error, "Failed to fetch system memory stats")
            return nil
        }
        
        let pageSize = Double(vm_kernel_page_size)
        
        let freeBytes = Double(stats.free_count) * pageSize
        let activeBytes = Double(stats.active_count) * pageSize
        let inactiveBytes = Double(stats.inactive_count) * pageSize
        let wiredBytes = Double(stats.wire_count) * pageSize
        let compressedBytes = Double(stats.compressor_page_count) * pageSize
        
        let usedBytes = activeBytes + inactiveBytes + wiredBytes + compressedBytes
        let totalBytes = usedBytes + freeBytes
        
        guard totalBytes > 0 else {
            return nil
        }
        
        let systemUtilization = (usedBytes / totalBytes) * 100.0
        
        // --- APP MEMORY STATS ---
        var taskInfo = task_vm_info_data_t()
        var taskInfoCount = mach_msg_type_number_t(MemoryLayout.size(ofValue: taskInfo)) / 4
        
        let taskResult = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(taskInfoCount)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &taskInfoCount)
            }
        }
        
        guard taskResult == KERN_SUCCESS else {
            os_log("%{public}@", log: log, type: .error, "Failed to get app memory usage")
            return nil
        }
        
        let appMemoryBytes = Double(taskInfo.phys_footprint)
        
        return MemoryReport(
            systemUsedBytes: usedBytes,
            systemFreeBytes: freeBytes,
            systemTotalBytes: totalBytes,
            systemUtilizationPercent: systemUtilization,
            appMemoryBytes: appMemoryBytes
        )
    }
}
