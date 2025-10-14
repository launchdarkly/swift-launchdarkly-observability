import Foundation
import KSCrashInstallations
import KSCrashRecording
import KSCrashDemangleFilter
import KSCrashFilters

// Reference: https://github.com/kstenerud/KSCrash/issues/187
final class LDCrashFilter: NSObject, CrashReportFilter {
    enum ReportSection: String {
        case incidentIdentifier = "Incident Identifier:"
        case exceptionType = "Exception Type:"
        case process = "Process:"
        case exceptionCodes = "Exception Codes:"
    }
    enum LaunchDarklyCrashFilterError: Error {
        case flushFailed
        case underlyingError(Error)
    }
    private let logsService: LogsService
    
    init(
        logsService: LogsService
    ) {
        self.logsService = logsService
    }
    
    func filterReports(
        _ reports: [any CrashReport],
        onCompletion: (([any CrashReport]?, (any Error)?) -> Void)? = nil
    ) {
        var jsonArray = [Any]()
        for item in reports {
            switch item {
            case let report as CrashReportDictionary:
                jsonArray.append(report.value)
            case let report as CrashReportString:
                jsonArray.append(report.value)
            case _ as CrashReportData:
//                "Unexpected non-dictionary/non-string report: \(report)"
                break
            default:
                /// Defaults means, there is no KSCrash representation for item, then no-op
                break
            }
        }

        do {
            for crash in jsonArray {
                let jsonData = try KSJSONCodec.encode(crash, options: .sorted)
                guard let crashReportString = String(data: jsonData, encoding: .utf8) else {
                    continue
                }
                let reportSections = crashReportString.components(separatedBy: "\\n")
                let incidentIdentifier = reportSections.first(where: { $0.contains(ReportSection.incidentIdentifier.rawValue) }) ?? ""
                let exceptionType = reportSections.first(where: { $0.contains(ReportSection.exceptionType.rawValue) }) ?? ""
                let exceptionCodes = reportSections.first(where: { $0.contains(ReportSection.exceptionCodes.rawValue) }) ?? ""
                
                var attributes = [String: AttributeValue]()
                attributes["exception.type"] = .string(exceptionType.replacingOccurrences(of: "\"", with: ""))
                attributes["exception.stacktrace"] = .string(crashReportString)
                attributes["exception.message"] = .string(exceptionCodes)
                
                logsService.recordLog(
                    message: incidentIdentifier.replacingOccurrences(of: "\"", with: ""),
                    severity: .fatal,
                    attributes: attributes
                )
            }
            
            Task { [weak self] in
                guard await self?.logsService.flush() == true else {
                    onCompletion?(reports, LaunchDarklyCrashFilterError.flushFailed)
                    return
                }
                onCompletion?(reports, nil)
            }
        } catch let error {
            onCompletion?(reports, error)
        }
    }
}
