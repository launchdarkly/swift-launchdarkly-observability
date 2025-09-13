import Foundation

import OpenTelemetrySdk
import OpenTelemetryApi

import Sampling

public final class SamplingTraceExporterDecorator: SpanExporter {
    private let exporter: SpanExporter
    private let sampler: ExportSampler
    
    public init(exporter: SpanExporter, sampler: ExportSampler) {
        self.exporter = exporter
        self.sampler = sampler
    }
    
    public func shutdown(explicitTimeout: TimeInterval?) {
        exporter.shutdown(explicitTimeout: explicitTimeout)
    }
    
    public func flush(
        explicitTimeout: TimeInterval?
    ) -> SpanExporterResultCode {
        exporter.flush(explicitTimeout: explicitTimeout)
    }
    
    public func export(
        spans: [SpanData],
        explicitTimeout: TimeInterval?
    ) -> SpanExporterResultCode {
        let sampledItems = sampleSpans(items: spans, sampler: sampler)
        guard !sampledItems.isEmpty else {
            return .success
        }
        
        return exporter.export(spans: sampledItems, explicitTimeout: explicitTimeout)
    }
}
