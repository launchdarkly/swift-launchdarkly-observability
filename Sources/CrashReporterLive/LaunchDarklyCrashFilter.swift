import Foundation

import KSCrashInstallations
import KSCrashRecording
import KSCrashDemangleFilter
import KSCrashFilters
@preconcurrency import OpenTelemetryApi
import OpenTelemetrySdk

import CrashReporter
import Common

// Reference: https://github.com/kstenerud/KSCrash/issues/187
final class LaunchDarklyCrashFilter: NSObject, CrashReportFilter {
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
    /// timeout: time to wait until all logs uploads are cancelled
    private let timeout: TimeInterval
    private let logger: Logger?
    private let otelBatchLogRecordProcessor: BatchLogRecordProcessor?
    
    init(logger: Logger?, otelBatchLogRecordProcessor: BatchLogRecordProcessor?, timeout: TimeInterval = 10) {
        self.logger = logger
        self.otelBatchLogRecordProcessor = otelBatchLogRecordProcessor
        self.timeout = timeout
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
                
                var attributes = [String: AttributeValue]()
                attributes[SemanticAttributes.exceptionType.rawValue] = .string(exceptionType.replacingOccurrences(of: "\"", with: ""))
                attributes[SemanticAttributes.exceptionStacktrace.rawValue] = .string(crashReportString)
                logger?.logRecordBuilder()
                    .setAttributes(attributes)
                    .setBody(.string(incidentIdentifier.replacingOccurrences(of: "\"", with: "")))
                    .setSeverity(.fatal)
                    .emit()
                
            }
            guard let result = otelBatchLogRecordProcessor?.forceFlush(explicitTimeout: timeout) else {
                onCompletion?(reports, LaunchDarklyCrashFilterError.flushFailed)
                return
            }
            switch result {
            case .success:
                onCompletion?(reports, nil)
            case .failure:
                onCompletion?(reports, LaunchDarklyCrashFilterError.flushFailed)
            }
        } catch let error {
            onCompletion?(reports, error)
        }
    }
}
