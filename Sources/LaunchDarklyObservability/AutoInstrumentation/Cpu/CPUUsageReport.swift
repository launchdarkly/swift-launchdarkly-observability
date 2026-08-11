#if !LD_COCOAPODS
import LaunchDarklyOtel
#endif
import Foundation

struct CPUUsageReport {
    let minUsagePercent: Double
    let maxUsagePercent: Double
    let averageUsagePercent: Double
    let durationSeconds: TimeInterval
}
