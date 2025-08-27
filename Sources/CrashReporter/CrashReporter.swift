public struct CrashReporter {
    public var install: () throws -> Void
    public var logPendingCrashReports: () -> Void
    
    public init(
        install: @escaping () throws -> Void,
        logPendingCrashReports: @escaping () -> Void
    ) {
        self.install = install
        self.logPendingCrashReports = logPendingCrashReports
    }
}
