#if os(iOS) || os(tvOS)
import Foundation
import MetricKit
import CryptoKit

/**
 The MXMetricManager shared object manages your subscription for receiving on-device daily metrics.

 MetricKit starts accumulating reports for your app after calling shared for the first time. To receive the reports, call add(_:) with an object that adopts the MXMetricManagerSubscriber protocol. The system then delivers metric reports at most once per day, and diagnostic reports immediately in iOS 15 and later and macOS 12 and
 later. The reports contain the metrics from the past 24 hours and any previously undelivered daily reports. To pause receiving reports, call remove(_:).

 The calls to add a subscriber and for receiving reports are safe to use in performance-sensitive code, such as app launch.
 
 MetricKit crash reports:
 - Are delivered after app relaunch
 - Are not immediate
 - May be batched or delayed
 - Depend on user diagnostics settings
 - Cannot access raw .ips files
 This is expected behavior.
 
 MetricKit intentionally:
 - Hides stack frames
 - Prevents symbol extraction
 - Prevents address inspection
 Instead, Apple allows:
 - Aggregated diagnostics
 - Privacy-safe serialization
 - Stable hashing for grouping
 
 - MetricKit does not tell you when an individual crash occurred
 - It only tells you the time window during which the crash happened
 - All diagnostics inside the payload share that window
 - This is a deliberate privacy design
 
 Apple intentionally:

 - Does NOT expose per-crash timestamps
 - Does NOT expose stack frames
 - Does NOT expose raw crash logs

 Instead, MetricKit provides:

 What you get &  Why
 - Time ranges  --> Privacy
 - Aggregation  -->  Power efficiency
 - Delayed delivery  -->  User consent
 - Serialized stacks  -->  De-identification
 */

struct MetricKitCrashReport: Codable, Error {
    let identifier: String
    let terminationReason: String?
    let signal: Int?
    let exceptionType: Int32?
    let callStack: Data

    // From MXDiagnosticPayload
    let payloadTimeRangeStart: Date
    let payloadTimeRangeEnd: Date
}

enum MachExceptionType: String, Codable {
    case badAccess        = "EXC_BAD_ACCESS"
    case badInstruction   = "EXC_BAD_INSTRUCTION"
    case arithmetic       = "EXC_ARITHMETIC"
    case emulation        = "EXC_EMULATION"
    case software         = "EXC_SOFTWARE"
    case breakpoint       = "EXC_BREAKPOINT"
    case syscall          = "EXC_SYSCALL"
    case machSyscall      = "EXC_MACH_SYSCALL"
    case rpcAlert         = "EXC_RPC_ALERT"
    case crash            = "EXC_CRASH"
    case resource         = "EXC_RESOURCE"
    case guardException   = "EXC_GUARD"
    case unknown          = "UNKNOWN"
}

extension MachExceptionType {
    init(exceptionTypeNumber: Int32?) {
        guard let rawValue = exceptionTypeNumber else {
            self = .unknown
            return
        }

        switch rawValue {
        case EXC_BAD_ACCESS:
            self = .badAccess
        case EXC_BAD_INSTRUCTION:
            self = .badInstruction
        case EXC_ARITHMETIC:
            self = .arithmetic
        case EXC_EMULATION:
            self = .emulation
        case EXC_SOFTWARE:
            self = .software
        case EXC_BREAKPOINT:
            self = .breakpoint
        case EXC_SYSCALL:
            self = .syscall
        case EXC_MACH_SYSCALL:
            self = .machSyscall
        case EXC_RPC_ALERT:
            self = .rpcAlert
        case EXC_CRASH:
            self = .crash
        case EXC_RESOURCE:
            self = .resource
        case EXC_GUARD:
            self = .guardException
        default:
            self = .unknown
        }
    }
}

fileprivate let formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

@available(iOS 15.0, tvOS 15.0, *)
final class MetricKitCrashReporter: NSObject, MXMetricManagerSubscriber, CrashReporting, AutoInstrumentation {
    private let logsApi: LogsApi
    private let log: OSLog
    private var _isStarted: Bool = false
    private let isStartedQueue = DispatchQueue(label: "com.launchdarkly.swift.MetricKitCrashReporter.isStartedQueue")
    private var isStarted: Bool {
        get { isStartedQueue.sync { _isStarted } }
        set { isStartedQueue.sync { _isStarted = newValue } }
    }
    
    init(logsApi: LogsApi, logger log: OSLog) {
        self.logsApi = logsApi
        self.log = log
        super.init()
    }

    // MARK: - Public API

    func start() {
        isStartedQueue.sync {
            guard _isStarted == false else { return }
            MXMetricManager.shared.add(self)
            _isStarted = true
        }
    }

    func stop() {
        isStartedQueue.sync {
            guard _isStarted else { return }
            MXMetricManager.shared.remove(self)
            _isStarted = false
        }
    }
    
    /// Diagnostics (crashes, hangs, exceptions)
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        payloads
            .forEach { payload in
                payload.crashDiagnostics?
                    .compactMap { $0 }
                    .forEach { crash in
                        processCrash(
                            crash,
                            timeRangeStart: payload.timeStampBegin,
                            timeRangeEnd: payload.timeStampEnd
                        )
                    }
            }
    }
    
    private func processCrash(
        _ crash: MXCrashDiagnostic,
        timeRangeStart: Date,
        timeRangeEnd: Date
    ) {
        
        let callStackJSON = crash.callStackTree.jsonRepresentation()
        
        let identifier = SHA256.hash(data: callStackJSON)
            .map { String(format: "%02x", $0) }
            .joined()
        
        let report = MetricKitCrashReport(
            identifier: identifier,
            terminationReason: crash.terminationReason,
            signal: crash.signal?.intValue,
            exceptionType: crash.exceptionType?.int32Value,
            callStack: callStackJSON,
            payloadTimeRangeStart: timeRangeStart,
            payloadTimeRangeEnd: timeRangeEnd
        )
        
        log(report)
    }
    
    private func log(_ report: MetricKitCrashReport) {
        var attributes = [String: AttributeValue]()
        attributes["exception.type"] = .string(MachExceptionType(exceptionTypeNumber: report.exceptionType).rawValue)
        attributes["exception.stacktrace"] = String(data: report.callStack, encoding: .utf8).map(AttributeValue.string)
        attributes["exception.message"] = report.terminationReason.map(AttributeValue.string)
        attributes["exception.identifier"] = .string(report.identifier)
        attributes["exception.start_time"] = .string(formatter.string(from: report.payloadTimeRangeStart))
        attributes["exception.end_time"] = .string(formatter.string(from: report.payloadTimeRangeEnd))
        
        logsApi.recordLog(
            message: report.identifier,
            severity: .fatal,
            attributes: attributes
        )
    }
    
    func logPendingCrashReports() {
        let pastDiagnosticPayloads: [MXDiagnosticPayload] = MXMetricManager.shared.pastDiagnosticPayloads
        didReceive(pastDiagnosticPayloads)
    }
}
#endif

