import Foundation
import OSLog
#if canImport(KSCrashRecording)
    import KSCrashInstallations
    import KSCrashRecording
    import KSCrashDemangleFilter
    import KSCrashFilters
#elseif canImport(KSCrash)
    import KSCrash
#endif

public protocol CrashReporting {
    func logPendingCrashReports()
}

final class KSCrashReportService {
    private let logsApi: LogsApi
    private let log: OSLog
    private let reportStore: CrashReportStore
    
    init(logsApi: LogsApi, log: OSLog) throws {        
        let reporter = KSCrash.shared
        
        guard let reportStore = reporter.reportStore else {
            throw InstrumentationError.unableToLoadReportStore
        }
        reportStore.sink = CrashReportFilterPipeline(filters: [
            CrashReportFilterDemangle(), // Handles symbol demangling
            CrashReportFilterAppleFmt(reportStyle: .symbolicated),
            LDCrashFilter(logsApi: logsApi)
        ])
        
        self.logsApi = logsApi
        self.log = log
        self.reportStore = reportStore
    }
}

extension KSCrashReportService: CrashReporting {
    public func logPendingCrashReports() {
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

extension KSCrashReportService {
    static func install() throws {
        let installation = CrashInstallationStandard.shared
        let config = KSCrashConfiguration()
        
        config.deadlockWatchdogInterval = 0
        config.enableMemoryIntrospection = false
        config.enableSigTermMonitoring = true
        config.monitors = [
            .signal,
            .nsException,
            .applicationState
        ]
        
        let storeConfig = CrashReportStoreConfiguration()
        storeConfig.maxReportCount = 10
        config.reportStoreConfiguration = storeConfig
        
        try installation.install(with: config)
    }
}
