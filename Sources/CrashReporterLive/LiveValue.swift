import Foundation
import KSCrashInstallations
import KSCrashRecording
import KSCrashDemangleFilter
import KSCrashFilters
@preconcurrency import OpenTelemetryApi
import OpenTelemetrySdk
import ResourceExtension

import CrashReporter
import Common

let dateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    return formatter
}()
let jsonDecoder = {
   let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .formatted(dateFormatter)
    return decoder
}()

extension CrashReporter {
    public static func build(
        logRecordBuilder: LogRecordBuilder
    ) -> Self {
        actor Reporter {
            private let logRecordBuilder: LogRecordBuilder
            
            init(logRecordBuilder: LogRecordBuilder) {
                self.logRecordBuilder = logRecordBuilder
            }
            
            func install() throws {
//                let installation = CrashInstallationStandard.shared
                let installation = CrashInstallationConsole.shared
                installation.printAppleFormat = true
                installation.isDemangleEnabled = true
                installation.isDoctorEnabled = true
                

                let config = KSCrashConfiguration()
                
                config.deadlockWatchdogInterval = 5.0
                config.enableMemoryIntrospection = true
                config.monitors = .all
                config.enableSigTermMonitoring = true
                let storeConfig = CrashReportStoreConfiguration()
                storeConfig.maxReportCount = 10
                config.reportStoreConfiguration = storeConfig
                
                try installation.install(with: config)
            }
            
            func fetchUnsentCrashReports() async throws -> [CrashDetails] {
                let reporter = KSCrash.shared
                
                guard let reportStore = reporter.reportStore else { return [] }
                reportStore.sink = CrashReportFilterPipeline(filters: [
                    CrashReportFilterDemangle(),
                    CrashReportFilterAppleFmt(reportStyle: .symbolicated),
                ])
                
                let reports = try reportStore.reportIDs.reduce([CrashDetails]()) { partialResult, reportId in
                    guard let id = reportId as? Int64 else { return partialResult }
                    let crashReportDictionary = reportStore.report(for: id)
                    guard let jsonObject = crashReportDictionary?.value else { return partialResult }
                    guard JSONSerialization.isValidJSONObject(jsonObject) else { return partialResult }
                    let data = try JSONSerialization.data(withJSONObject: jsonObject, options: .fragmentsAllowed)
                    guard let jsonString = String(data: data, encoding: .utf8) else { return partialResult }
                    
                    
                    let decodedReport: CrashReportInfo?
                    do {
                        decodedReport = try jsonDecoder.decode(CrashReportInfo.self, from: data)
                    } catch let error {
                        decodedReport = nil
                    }
                    
                    return partialResult + [CrashDetails(reportId: id, rawReport: jsonString, report: decodedReport)]
                }
                return reports
            }
            
            func logCrashReports() async throws {
                let reports = try await fetchUnsentCrashReports()
                
                for item in reports {
                    var attributes = [String: AttributeValue]()
                    attributes[SemanticAttributes.threadId.rawValue] = item.info.flatMap { AttributeValue.int($0.system.processID) }
                    attributes[SemanticAttributes.threadName.rawValue] = item.info.flatMap { AttributeValue.string($0.system.processName) }
                    attributes[SemanticAttributes.exceptionStacktrace.rawValue] = item.info.flatMap { JSON.stringify($0.crash.threads) }
                        .map { AttributeValue.string($0) }
                    logRecordBuilder
                        .setSeverity(.fatal)
                        .setAttributes(attributes)
//                        .setBody(.string(item.rawReport))
                        .setBody(.string(item.info?.crash.error.type ?? "Unknown error"))
                        .emit()
                    KSCrash.shared.reportStore?.deleteReport(with: item.reportId)
                }
            }
        }
        
        let reporter = Reporter(logRecordBuilder: logRecordBuilder)
        return .init(
            install: { try await reporter.install() },
            fetchReports: { try await reporter.fetchUnsentCrashReports() },
            logCrashReports: { try await reporter.logCrashReports() }
        )
    }
}
