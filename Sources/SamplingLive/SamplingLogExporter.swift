import Foundation

import OpenTelemetrySdk
import OpenTelemetryApi

import Sampling

public final class SamplingLogExporterDecorator: LogRecordExporter {
    private let exporter: LogRecordExporter
    private let sampler: ExportSampler
    
    public init(exporter: LogRecordExporter, sampler: ExportSampler) {
        self.exporter = exporter
        self.sampler = sampler
    }
    
    public func forceFlush(
        explicitTimeout: TimeInterval?
    ) -> ExportResult {
        exporter.forceFlush(explicitTimeout: explicitTimeout)
    }
    
    public func shutdown(
        explicitTimeout: TimeInterval?
    ) {
        exporter.shutdown(explicitTimeout: explicitTimeout)
    }
    
    public func export(
        logRecords: [ReadableLogRecord],
        explicitTimeout: TimeInterval?
    ) -> ExportResult {
        let sampledItems = sampleLogs(
            items: logRecords,
            sampler: sampler
        )
        guard !sampledItems.isEmpty else {
            return .success
        }
        
        return exporter.export(logRecords: logRecords, explicitTimeout: explicitTimeout)
    }
    
    
}
