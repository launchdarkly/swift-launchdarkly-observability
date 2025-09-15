import OpenTelemetrySdk
import OpenTelemetryApi

import Sampling

func sampleSpans(
    items: [SpanData],
    sampler: ExportSampler
) -> [SpanData] {
    if !sampler.isSamplingEnabled() {
        return items
    }
    
    var omittedSpansIds = Set<SpanId>()
    var spanById = [SpanId: SpanData]()
    var childrenByParentId = [SpanId: [SpanId]]()
    
    /// The first pass we sample items which are directly impacted by a sampling decision.
    /// We also build a map of children spans by parent span id, which allows us to quickly traverse the span tree.
    for item in items {
        if let parentSpanId = item.parentSpanId {
            childrenByParentId[parentSpanId, default: []].append(item.spanId)
        }
        
        let sampleResult = sampler.sampleSpan(item)
        if sampleResult.sample {
            var mutableSpanData = item
            mutableSpanData.settingAttributes(
                item.attributes.merging(sampleResult.attributes ?? [:], uniquingKeysWith: { current, new in current })
            ) // Merge, prioritizing values from spanData for duplicate keys
            spanById[item.spanId] = mutableSpanData
        } else {
            omittedSpansIds.insert(item.spanId)
        }
    }
    
    /// Find all children of spans that have been sampled out and remove them.
    /// Repeat until there are no more children to remove.
    while let omittedSpanId = omittedSpansIds.popFirst() {
        
        guard let affectedSpans = childrenByParentId[omittedSpanId] else { continue }
        
        for spanIdToRemove in affectedSpans {
            spanById.removeValue(forKey: spanIdToRemove)
            omittedSpansIds.insert(spanIdToRemove)
        }
    }
    
    return items.compactMap { spanById[$0.spanId] }
}
