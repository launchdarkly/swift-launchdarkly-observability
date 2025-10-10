import Foundation
import OSLog

import ApplicationServices

extension CpuUsageMeterService {
    public static let noOp: Self = .init(startMonitoring: {}, stopMonitoring: {})
    
    public static func build(
        options: Options,
        metricsService: MetricsService
    ) -> Self {
        guard let cpuOptions = options.systemMetrics.first(where: { $0.system == .cpu }), cpuOptions.state == .enabled else {
            return .noOp
        }
        
        let cpuService = CPUUsageService()
        let cpuMonitor = Monitor<CpuUsage>(
            interval: cpuOptions.pollingFrequency,
            sampleProvider: { cpuService.getCPUUsage() }) { usage in
                metricsService.recordMetric(
                    metric: .init(
                        name: SemanticConvention.System.systemCpuUtilization,
                        value: usage.total
                    )
                )
            }
        
        return .init(
            startMonitoring: { cpuMonitor.start() },
            stopMonitoring: { cpuMonitor.stop() }
        )
    }
}
