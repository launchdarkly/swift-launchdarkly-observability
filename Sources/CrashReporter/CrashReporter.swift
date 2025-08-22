public struct CrashDetails: Sendable {
    public let reportId: Int64
    public let rawReport: String
    public let info: CrashReportInfo?
    
    public init(reportId: Int64, rawReport: String, report: CrashReportInfo? = nil) {
        self.reportId = reportId
        self.rawReport = rawReport
        self.info = report
    }
}

public struct CrashReporter: Sendable {
    public var install: @Sendable () async throws -> Void
    public var fetchReports: @Sendable () async throws -> [CrashDetails]
    public var logCrashReports: @Sendable () async throws -> Void
    
    public init(
        install: @escaping @Sendable () async throws -> Void,
        fetchReports: @escaping @Sendable () async throws -> [CrashDetails],
        logCrashReports: @escaping @Sendable () async throws -> Void
    ) {
        self.install = install
        self.fetchReports = fetchReports
        self.logCrashReports = logCrashReports
    }
    
    public func fetchReports() async throws -> [CrashDetails] {
        try await fetchReports()
    }
}
