import Foundation
import OSLog

import ApplicationServices

import KSCrashInstallations
import KSCrashRecording
import KSCrashDemangleFilter
import KSCrashFilters

final class KSCrashReportService {
    private let logsService: LogsService
    private let log: OSLog
    
    init(logsService: LogsService, log: OSLog) throws {
        let installation = CrashInstallationStandard.shared
        let config = KSCrashConfiguration()
        
        config.deadlockWatchdogInterval = 0
        config.enableMemoryIntrospection = true
        config.monitors = .all
        config.enableSigTermMonitoring = true
        let storeConfig = CrashReportStoreConfiguration()
        storeConfig.maxReportCount = 10
        config.reportStoreConfiguration = storeConfig
        
        try installation.install(with: config)
        
        self.logsService = logsService
        self.log = log
    }
    
    func logPendingCrashReports() -> Void {
        let reporter = KSCrash.shared
        
        guard let reportStore = reporter.reportStore else { return }
        reportStore.sink = CrashReportFilterPipeline(filters: [
            CrashReportFilterDemangle(), // Handles symbol demangling
            CrashReportFilterAppleFmt(reportStyle: .symbolicated),
            LDCrashFilter(logsService: logsService)
        ])
        reportStore.sendAllReports { [weak self] anyReports, error in
            guard let self else { return }
            if let error {
                os_log("%{public}@", log: log, type: .error, "logging pending reports failed with error: \(error)")
            } else {
                os_log("%{public}@", log: log, type: .info, "logging pending succeeded")
            }
        }
    }
}
