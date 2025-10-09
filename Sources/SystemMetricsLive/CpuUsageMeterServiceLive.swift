import Foundation
import OSLog

import ApplicationServices

extension CpuUsageMeterService {
    public static let noOp: Self = .init(startMonitoring: {}, stopMonitoring: {})
    
    public static func build(
        monitoringInterval: TimeInterval = 2,
        metricsService: MetricsService,
        log: OSLog
    ) -> Self {
        
        let systemCPUUtilizationService = SystemCPUUtilizationService()
        
        let facade = CpuUsageMeterServiceFacade(
            monitoringInterval: monitoringInterval,
            metricsService: metricsService,
            systemCPUUtilizationService: systemCPUUtilizationService,
            log: log
        )
        
        return .init(
            startMonitoring: {
                facade.startMonitoring()
            },
            stopMonitoring: {
                facade.stopMonitoring()
            }
        )
    }
}
final class CpuUsageMeterServiceFacade {
    private let monitoringInterval: TimeInterval
    private let metricsService: MetricsService
    private let systemCPUUtilizationService: SystemCPUUtilizationService
    private let log: OSLog
    private var tasks = [UUID]()
    
    private let scheduler = Scheduler()
    
    init(
        monitoringInterval: TimeInterval = 2,
        metricsService: MetricsService,
        systemCPUUtilizationService: SystemCPUUtilizationService,
        log: OSLog
    ) {
        self.monitoringInterval = monitoringInterval
        self.metricsService = metricsService
        self.systemCPUUtilizationService = systemCPUUtilizationService
        self.log = log
    }
    
    deinit {
        tasks.forEach(scheduler.stopRepeating(id:))
        tasks.removeAll()
    }
    
    func startMonitoring() {
        var service = systemCPUUtilizationService
        let log = log
        let metrics = metricsService
        
        do {
            /// Get initial snapshot
            try service.snapshot()
            tasks.append(
                scheduler.scheduleRepeating(
                    every: monitoringInterval) {
                        do {
                            let utilizations = try service.utilizationSinceLastSnapshot()
                            for cpu in utilizations {
                                metrics.recordMetric(
                                    metric: .init(
                                        name: SemanticConvention.System.systemCpuUtilization,
                                        value: cpu.byMode[.user] ?? 0.0,
                                        attributes: [
                                            SemanticConvention.System.cpuLogicalNumber: .int(cpu.cpuIndex),
                                            SemanticConvention.System.cpuMode: .string("user")
                                        ]
                                    )
                                )
                            }
                        } catch {
                            os_log("%{public}@", log: log, type: .error, "utilizationSinceLastSnapshot failed with error: \(error)")
                        }
                    }
            )
        } catch {
            os_log("%{public}@", log: log, type: .error, "get initial cpu snapshot failed with error: \(error)")
        }
        
    }
    
    func stopMonitoring() {
        tasks.forEach(scheduler.stopRepeating(id:))
    }
}
