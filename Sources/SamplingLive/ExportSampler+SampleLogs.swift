import OpenTelemetrySdk

import Sampling

extension ExportSampler {
    func sampleLogs(
        items: [ReadableLogRecord]
    ) -> [ReadableLogRecord] {
        guard isSamplingEnabled() else {
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
