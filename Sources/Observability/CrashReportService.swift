public struct CrashReportService {
    public var logPendingCrashReports: () -> Void
    
    public init(
        logPendingCrashReports: @escaping () -> Void
    ) {
        self.logPendingCrashReports = logPendingCrashReports
    }
}
