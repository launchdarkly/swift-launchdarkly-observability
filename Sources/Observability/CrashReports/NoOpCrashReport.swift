struct NoOpCrashReport: CrashReporting {
    func logPendingCrashReports() {}
}
