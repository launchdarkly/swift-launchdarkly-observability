import OpenTelemetrySdk
import OpenTelemetryApi

extension ExportSampler {
    func sampledLog(_ record: ReadableLogRecord) -> ReadableLogRecord? {
        guard isSamplingEnabled else {
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
    
    /// Remove when is not needed anymore, kept for compatibility purposes only
    func sampleLogs(
        items: [ReadableLogRecord]
    ) -> [ReadableLogRecord] {
        guard isSamplingEnabled else {
            return items
        }
        
        return items.compactMap { item in
            let sampleResult = sampleLog(item)
            guard sampleResult.sample else {
                return nil
            }
            return ReadableLogRecord(
                resource: item.resource,
                instrumentationScopeInfo: item.instrumentationScopeInfo,
                timestamp: item.timestamp,
                observedTimestamp: item.observedTimestamp,
                spanContext: item.spanContext,
                severity: item.severity,
                body: item.body,
                attributes: item.attributes.merging(sampleResult.attributes ?? [:], uniquingKeysWith: { current, new in current }) // Merge, prioritizing values from logRecord for duplicate keys
            )
        }
    }
}
