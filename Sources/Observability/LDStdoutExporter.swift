import Foundation

import os

import OpenTelemetrySdk
import OpenTelemetryApi

import Common


final class LDStdoutExporter: LogRecordExporter {
    private let loggerName: String
    
    init(loggerName: String) {
        self.loggerName = loggerName
    }
    
    public func forceFlush(
        explicitTimeout: TimeInterval?
    ) -> ExportResult {
        .success
    }
    
    public func shutdown(
        explicitTimeout: TimeInterval?
    ) {
        
    }
    
    public func export(
        logRecords: [ReadableLogRecord],
        explicitTimeout: TimeInterval?
    ) -> ExportResult {

        for log in logRecords {
            guard let message = JSON.stringify(log) else { continue }
            
            os_log("%{public}@", log: .default, type: .info, message)
        }
        
        return .success
    }
}
