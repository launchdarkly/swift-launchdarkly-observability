import Foundation
import OpenTelemetrySdk
import OpenTelemetryApi

final class SamplingLogExporterDecorator: LogRecordExporter {
    private let exporter: LogRecordExporter
    private let sampler: ExportSampler
    
    init(exporter: LogRecordExporter, sampler: ExportSampler) {
        self.exporter = exporter
        self.sampler = sampler
    }
    
    func forceFlush(
        explicitTimeout: TimeInterval?
    ) -> ExportResult {
        exporter.forceFlush(explicitTimeout: explicitTimeout)
    }
    
    func shutdown(
        explicitTimeout: TimeInterval?
    ) {
        exporter.shutdown(explicitTimeout: explicitTimeout)
    }
    
    func export(
        logRecords: [ReadableLogRecord],
        explicitTimeout: TimeInterval?
    ) -> ExportResult {
        let sampledItems = sampler.sampleLogs(
            items: logRecords
        )
        guard !sampledItems.isEmpty else {
            return .success
        }
        
        return exporter.export(logRecords: sampledItems, explicitTimeout: explicitTimeout)
    }
}
