#if os(iOS) || os(tvOS)
import Foundation
import MetricKit
import CryptoKit

/**
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

struct CrashReport: Codable {
    let identifier: String
    let terminationReason: String?
    let signal: Int?
    let exceptionType: Int?
    let callStack: Data

    // From MXDiagnosticPayload
    let payloadTimeRangeStart: Date
    let payloadTimeRangeEnd: Date
}

@available(iOS 14.0, tvOS 14.0, *)
final class MetricKitCrashReporter: NSObject, MXMetricManagerSubscriber {
    private override init() {
        super.init()
    }

    // MARK: - Public API

    func start() {
        MXMetricManager.shared.add(self)
    }

    func stop() {
        MXMetricManager.shared.remove(self)
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
        
        let report = CrashReport(
            identifier: identifier,
            terminationReason: crash.terminationReason,
            signal: crash.signal?.intValue,
            exceptionType: crash.exceptionType?.intValue,
            callStack: callStackJSON,
            payloadTimeRangeStart: timeRangeStart,
            payloadTimeRangeEnd: timeRangeEnd
        )
        
        sendToServer(report)
    }
    
    private func sendToServer(_ report: CrashReport) {
        
    }
}
#endif

