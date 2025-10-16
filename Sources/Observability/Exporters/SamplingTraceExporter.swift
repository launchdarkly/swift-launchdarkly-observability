import Foundation

import OpenTelemetrySdk
import OpenTelemetryApi

final class SamplingTraceExporterDecorator: SpanExporter {
    private let exporter: SpanExporter
    private let sampler: ExportSampler
    
    init(exporter: SpanExporter, sampler: ExportSampler) {
        self.exporter = exporter
        self.sampler = sampler
    }
    
    func shutdown(explicitTimeout: TimeInterval?) {
        exporter.shutdown(explicitTimeout: explicitTimeout)
    }
    
    func flush(
        explicitTimeout: TimeInterval?
    ) -> SpanExporterResultCode {
        exporter.flush(explicitTimeout: explicitTimeout)
    }
    
    func export(
        spans: [SpanData],
        explicitTimeout: TimeInterval?
    ) -> SpanExporterResultCode {
        let sampledItems = sampler.sampleSpans(items: spans)
        guard !sampledItems.isEmpty else {
            return .success
        }
        
        return exporter.export(spans: sampledItems, explicitTimeout: explicitTimeout)
    }
}
