import Foundation

// MARK: - CrashReport
public struct CrashReportInfo: Codable, Hashable, Sendable {
    public let report: Report
    public let system: System
    public let crash: Crash

    public enum CodingKeys: String, CodingKey {
        case report = "report"
        case system = "system"
        case crash = "crash"
    }

    public init(report: Report, system: System, crash: Crash) {
        self.report = report
        self.system = system
        self.crash = crash
    }
}
