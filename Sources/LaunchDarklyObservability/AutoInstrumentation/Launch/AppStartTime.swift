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

@objcMembers
public final class AppStartTime: NSObject {
    public struct AppStartStats {
        public let startTime: TimeInterval
        public let startDate: Date
    }
    
    /// Captures uptime when initialized.
    public static var stats: AppStartStats = {
        let t = ProcessInfo.processInfo.systemUptime
        let d = Date()
        
        let installation = CrashInstallationStandard.shared
        let config = KSCrashConfiguration()
        
        config.deadlockWatchdogInterval = 0
        config.enableMemoryIntrospection = false
        config.monitors = [
            .signal,
            .nsException,
            .applicationState
        ]
        config.enableSigTermMonitoring = true
        let storeConfig = CrashReportStoreConfiguration()
        storeConfig.maxReportCount = 10
        config.reportStoreConfiguration = storeConfig
        
        do {
            try installation.install(with: config)
        } catch {
            os_log("KSCrash installation failed with error: %{public}@", log: .default, type: .error, error.localizedDescription)
        }

        return .init(startTime: t, startDate: d)
    }()
}

// Expose a function Swift can call from C
//@_silgen_name("SwiftStartupMetricsInitialize")
@_cdecl("SwiftStartupMetricsInitialize")
public func SwiftStartupMetricsInitialize() {
    _ = AppStartTime.stats
}
