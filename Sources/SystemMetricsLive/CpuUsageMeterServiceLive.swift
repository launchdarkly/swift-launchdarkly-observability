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
        let facade = CpuUsageMeterServiceFacade(
            monitoringInterval: monitoringInterval,
            metricsService: metricsService,
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
    private let log: OSLog
    private var tasks = [UUID]()
    
    private let scheduler = Scheduler()
    
    init(
        monitoringInterval: TimeInterval = 2,
        metricsService: MetricsService,
        log: OSLog
    ) {
        self.monitoringInterval = monitoringInterval
        self.metricsService = metricsService
        self.log = log
    }
    
    deinit {
        tasks.forEach(scheduler.stopRepeating(id:))
    }
    
    func startMonitoring() {
        var cpu = CPULoad()
        let log = log
        let metrics = metricsService
        tasks.append(
            scheduler.scheduleRepeating(
                every: monitoringInterval) {
                    do {
                        let statistics = try cpu.cpuUsage()
                        let physicalCores = Int(cpu.physicalCoresCount())
                        
                        /// measure user
                        metrics.recordMetric(
                            metric: .init(
                                name: SemanticConvention.System.systemCpuUtilization,
                                value: statistics.user,
                                attributes: [
                                    SemanticConvention.System.cpuLogicalNumber: .int(physicalCores),
                                    SemanticConvention.System.cpuMode: .string("user")
                                ]
                            )
                        )
                        /// measure idle
                        metrics.recordMetric(
                            metric: .init(
                                name: SemanticConvention.System.systemCpuUtilization,
                                value: statistics.idle,
                                attributes: [
                                    SemanticConvention.System.cpuLogicalNumber: .int(physicalCores),
                                    SemanticConvention.System.cpuMode: .string("idle")
                                ]
                            )
                        )
                    } catch {
                        os_log("%{public}@", log: log, type: .error, "failed to get user CPU usage")
                    }
                }
        )
    }
    
    func stopMonitoring() {
        tasks.forEach(scheduler.stopRepeating(id:))
    }
}
