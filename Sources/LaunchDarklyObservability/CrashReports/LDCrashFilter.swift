#if !LD_COCOAPODS
import LaunchDarklyOtel
#endif
import Foundation
#if canImport(KSCrashRecording)
    import KSCrashInstallations
    import KSCrashRecording
    import KSCrashDemangleFilter
    import KSCrashFilters
#elseif canImport(KSCrash)
    import KSCrash
#endif

// Reference: https://github.com/kstenerud/KSCrash/issues/187
//
// Consumes the raw (demangled) KSCrash report dictionary and emits a fatal log
// record whose `exception.stacktrace` is the structured "ld-apple-1" payload
// (per-frame image UUID + image-relative offset). The backend symbolicates these
// frames against the .dsymmap maps uploaded via `ldcli symbols upload
// --type apple-dsym`. Because this reads the raw report rather than the Apple
// text format, the pipeline no longer includes CrashReportFilterAppleFmt.
final class LDCrashFilter: NSObject, CrashReportFilter {
    enum LaunchDarklyCrashFilterError: Error {
        case flushFailed
        case underlyingError(Error)
    }
    private let logsApi: LogRecording
    
    init(
        logsApi: LogRecording
    ) {
        self.logsApi = logsApi
    }
    
    func filterReports(
        _ reports: [any CrashReport],
        onCompletion: (([any CrashReport]?, (any Error)?) -> Void)? = nil
    ) {
        do {
            for item in reports {
                guard let report = item as? CrashReportDictionary else {
                    // Non-dictionary reports (strings/data) carry no structured
                    // fields to symbolicate; skip them.
                    continue
                }
                let jsonData = try KSJSONCodec.encode(report.value, options: .sorted)
                // Always emit fatal telemetry for a crash report, even when the
                // structured backtrace can't be built — otherwise KSCrash treats
                // the (silent) completion as success and discards the report.
                let crash = try AppleCrashPayloadBuilder.makeStructuredCrash(fromReportData: jsonData)

                var attributes = [String: AttributeValue]()
                attributes["exception.type"] = .string(crash.exceptionType)
                if let stackTraceJSON = crash.stackTraceJSON {
                    attributes["exception.stacktrace"] = .string(stackTraceJSON)
                }
                if let message = crash.exceptionMessage {
                    attributes["exception.message"] = .string(message)
                }

                logsApi.recordLog(
                    message: crash.incidentIdentifier,
                    severity: .fatal,
                    attributes: attributes
                )
            }
            onCompletion?(reports, nil)
        } catch let error {
            onCompletion?(reports, error)
        }
    }
}
