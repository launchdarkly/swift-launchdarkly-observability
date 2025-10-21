struct MemoryReport {
    // System-wide memory
    let systemUsedMB: Double
    let systemFreeMB: Double
    let systemTotalMB: Double
    let systemUtilizationPercent: Double

    // App-specific memory
    let appMemoryMB: Double
}
