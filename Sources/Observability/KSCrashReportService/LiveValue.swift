import OSLog

extension CrashReportService {
    public static func build(
        logsService: LogsService,
        options: Options
    ) throws -> Self {
        let service = try KSCrashReportService(logsService: logsService, log: options.log)
        
        return .init(
            logPendingCrashReports: { service.logPendingCrashReports() }
        )
    }
}
