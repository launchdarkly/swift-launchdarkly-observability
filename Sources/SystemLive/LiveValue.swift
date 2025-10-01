import Foundation
import OSLog

import OpenTelemetryApi

import Common
import Instrumentation
import System

extension SystemInfo {
    public static let noOp: Self = .init(startMonitoring: {}, stopMonitoring: {})
    
    public static func build(
        monitoringInterval: TimeInterval = 2,
        instrumentation: Instrumentation,
        logger: ObservabilityLogger = .init()
    ) -> Self {
        
        let facade = SystemInfoFacade(
            monitoringInterval: monitoringInterval,
            instrumentationManager: instrumentation,
            logger: logger
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

final class SystemInfoFacade {
    private let monitoringInterval: TimeInterval
    private let instrumentationManager: Instrumentation
    private let logger: ObservabilityLogger
    private var tasks = [UUID]()
    
    private let scheduler = Scheduler()
    
    init(
        monitoringInterval: TimeInterval = 2,
        instrumentationManager: Instrumentation,
        logger: ObservabilityLogger
    ) {
        self.monitoringInterval = monitoringInterval
        self.instrumentationManager = instrumentationManager
        self.logger = logger
    }
    
    deinit {
        tasks.forEach(scheduler.stopRepeating(id:))
    }
    
    func startMonitoring() {
        let cpu = CPULoad()
        let log = logger.log
        let instrumentation = instrumentationManager
        tasks.append(
            scheduler.scheduleRepeating(
                every: monitoringInterval) {
                    do {
                        let statistics = try cpu.cpuUsage()
                        let physicalCores = Int(cpu.physicalCoresCount())
                        instrumentation.recordMetric(
                            metric: .init(
                                name: LDSemanticAttribute.System.systemCpuUtilization,
                                value: statistics.user,
                                attributes: [
                                    LDSemanticAttribute.System.cpuLogicalNumber: .int(physicalCores),
                                    LDSemanticAttribute.System.cpuMode: .string("user")
                                ]
                            )
                        )
                        
                        instrumentation.recordMetric(
                            metric: .init(
                                name: LDSemanticAttribute.System.systemCpuUtilization,
                                value: statistics.user,
                                attributes: [
                                    LDSemanticAttribute.System.cpuLogicalNumber: .int(physicalCores),
                                    LDSemanticAttribute.System.cpuMode: .string("idle")
                                ]
                            )
                        )
                        
                        let info = """
                            user: \(statistics.user) \
                            system: \(statistics.system) \
                            idle: \(statistics.idle) \
                            nice: \(statistics.nice)
                            """
                        os_log("%{public}@", log: log, type: .debug, info)
                    } catch {
                        os_log("%{public}@", log: log, type: .error, "failed to get CPU usage")
                    }
                }
        )
    }
    
    func stopMonitoring() {
        tasks.forEach(scheduler.stopRepeating(id:))
    }
}
