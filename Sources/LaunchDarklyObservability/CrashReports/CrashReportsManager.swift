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
    private let logsApi: InternalLogsApi
    private let log: OSLog
    private let reportStore: CrashReportStore
    
    init(logsApi: InternalLogsApi, log: OSLog) throws {
        let reporter = KSCrash.shared
        
        guard let reportStore = reporter.reportStore else {
            throw InstrumentationError.unableToLoadReportStore
        }
        // Demangle on-device symbols (used as the fallback label), then hand the
        // raw report dictionary to LDCrashFilter, which builds the structured
        // "ld-apple-1" payload. CrashReportFilterAppleFmt is intentionally omitted:
        // it flattens the report to Apple crash text and would drop the per-frame
        // image UUID / load address the backend needs to symbolicate from .ldsm maps.
        reportStore.sink = CrashReportFilterPipeline(filters: [
            CrashReportFilterDemangle(), // Handles symbol demangling
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
            .machException,
            .signal,
            .cppException,
            .nsException,
            /// .mainThreadDeadlock, conflicts with config.deadlockWatchdogInterval = 0
            .userReported,
            .system,
            .applicationState,
            .memoryTermination
        ]
        
        let storeConfig = CrashReportStoreConfiguration()
        storeConfig.maxReportCount = 10
        config.reportStoreConfiguration = storeConfig
        
        try installation.install(with: config)
    }
}
