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

extension CrashReporter {
    public static func otelReporter(
        logger: Logger?,
        otelBatchLogRecordProcessor: BatchLogRecordProcessor?,
        completion: (() -> Void)?
    ) -> Self {
        final class Reporter: @unchecked Sendable {
            private let logger: Logger?
            private let otelBatchLogRecordProcessor: BatchLogRecordProcessor?
            private let completion: (() -> Void)?
            
            init(
                logger: Logger?,
                otelBatchLogRecordProcessor: BatchLogRecordProcessor?,
                completion: (() -> Void)?
            ) {
                self.logger = logger
                self.otelBatchLogRecordProcessor = otelBatchLogRecordProcessor
                self.completion = completion
            }
            
            func install() throws {
                let installation = CrashInstallationStandard.shared
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
            
            func logPendingCrashReports() -> Void {
                let reporter = KSCrash.shared
                
                guard let reportStore = reporter.reportStore else { return }
                reportStore.sink = CrashReportFilterPipeline(filters: [
                    CrashReportFilterDemangle(),
                    CrashReportFilterAppleFmt(reportStyle: .symbolicated),
                    LaunchDarklyCrashFilter(
                        logger: logger,
                        otelBatchLogRecordProcessor: otelBatchLogRecordProcessor
                    )
                ])
                reportStore.sendAllReports { [weak self] anyReports, error in
                    self?.completion?()
                }
            }
        }
        
        let reporter = Reporter(
            logger: logger,
            otelBatchLogRecordProcessor: otelBatchLogRecordProcessor,
            completion: completion
        )
        return .init(
            install: { try reporter.install() },
            logPendingCrashReports: { reporter.logPendingCrashReports() }
        )
    }
}
