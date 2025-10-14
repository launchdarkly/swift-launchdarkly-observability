import OpenTelemetrySdk
import OpenTelemetryApi

extension ExportSampler {
    func sampleLogs(
        items: [ReadableLogRecord]
    ) -> [ReadableLogRecord] {
        guard isSamplingEnabled() else {
            return items
        }
        
        return items.compactMap { item in
            sampledLog(item)
        }
    }
    
    func sampledLog(_ record: ReadableLogRecord) -> ReadableLogRecord? {
        guard isSamplingEnabled() else {
            return record
        }
        
        let sampleResult = sampleLog(record)
        guard sampleResult.sample else {
            return nil
        }
        
        return ReadableLogRecord(
            resource: record.resource,
            instrumentationScopeInfo: record.instrumentationScopeInfo,
            timestamp: record.timestamp,
            observedTimestamp: record.observedTimestamp,
            spanContext: record.spanContext,
            severity: record.severity,
            body: record.body,
            attributes: record.attributes.merging(sampleResult.attributes ?? [:], uniquingKeysWith: { current, new in current }) // Merge, prioritizing values from logRecord for duplicate keys
        )
    }
}
