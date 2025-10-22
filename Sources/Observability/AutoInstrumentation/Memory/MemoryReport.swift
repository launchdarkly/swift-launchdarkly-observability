struct MemoryReport {
    // System-wide memory
    let systemUsedBytes: Double
    let systemFreeBytes: Double
    let systemTotalBytes: Double
    let systemUtilizationPercent: Double

    // App-specific memory
    let appMemoryMB: Double
}
