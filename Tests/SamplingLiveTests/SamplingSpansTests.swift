import Testing

@testable import OpenTelemetrySdk
import OpenTelemetryApi
@testable import Observability

struct SamplingSpansTests {
    
    @Test("Given a set of spans and a sampler, when sampling is disabled, then should return all spans")
    func samplingDisabled() {
        let spans = (1...3).map { makeMockSpanData(name: "span\($0)") }
        let sampler = ExportSampler.fake(isSamplingEnabled: false)
        
        let result = sampler.sampleSpans(items: spans)
        
        #expect(result.count == spans.count)
        for (r, sd) in zip(result, spans) {
            #expect(r.spanId == sd.spanId)
            #expect(r.name == sd.name)
        }
    }
    
    @Test("Given an empty array of spans and a sampler, when sampling is enabled, then should return handle empty array")
    func samplingEnabledEmptySpansArray() {
        let spans = [SpanData]()
        let sampler = ExportSampler.fake(isSamplingEnabled: true)
        
        let result = sampler.sampleSpans(items: spans)
        
        #expect(result.isEmpty)
    }
    
    @Test("Given an array of spans and a sampler, when sampling is enabled and no span is sampled, then should return empty result")
    func samplingEnabledNoSamplingThenEmptyResult() {
        let spans = (1...3).map { makeMockSpanData(name: "span\($0)") }
        let sampler = ExportSampler.fake(
            sampleSpan: { _ in .init(sample: false) },
            isSamplingEnabled: true
        )
        
        let result = sampler.sampleSpans(items: spans)
        
        #expect(result.isEmpty)
    }
    
    @Test("Given an array of spans and a sample, when sampling is enabled and all are sampled without additional attributes, then should return all")
    func samplingEnabledAllSampledWithoutAdditionalAttributes() {
        let sampler = ExportSampler.fake(
            sampleSpan: { _ in .init(sample: true, attributes: nil) },
            isSamplingEnabled: true
        )
        let spans = (1...3).map { makeMockSpanData(name: "span\($0)") }
        
        let result = sampler.sampleSpans(items: spans)
        
        #expect(result.count == spans.count)
        #expect(result == spans)
    }
    
    @Test("Given an array of spans, when some spans are sampled, then should return a subset of the spans")
    func samplingEnabledSomeSampled() {
        let sampler = ExportSampler.fake(
            sampleSpan: { span in
                if span.name == "span2" {
                    return .init(sample: false)
                } else {
                    return .init(sample: true)
                }
            },
            isSamplingEnabled: true
        )
        let span1 = makeMockSpanData(name: "span1")
        let span2 = makeMockSpanData(name: "span2")
        let span3 = makeMockSpanData(name: "span1")
        let spans = [span1, span2, span3]
        
        let result = sampler.sampleSpans(items: spans)
        
        
        #expect(result.count == 2)
        #expect(span1 == result[0])
        #expect(span3 == result[1])
    }
    
    @Test(
    """
    Given an array of spans, 
    when some spans are sampled and sampling attributes are provided, 
    then should add the sampling attributes and preserve the original ones
    """
    )
    func samplingEnabledWithSamplingAttributes() {
        let originalAttributes = [
            "service.name": OpenTelemetryApi.AttributeValue.string("api-service"),
            "environment": AttributeValue.string("production")
        ]
        
        let originalSpan = makeMockSpanData(name: "test-span", parentSpanId: .random(), attributes: originalAttributes)
        
        let spans = [originalSpan]
        
        let samplingAttributes = [
            SemanticConvention.attributeSamplingRatio:  OpenTelemetryApi.AttributeValue.int(42)
        ]
        
        let sampler = ExportSampler.fake(
            sampleSpan: { span in
                if span.name == "test-span" {
                    return .init(sample: true, attributes: samplingAttributes)
                } else {
                    return .init(sample: true)
                }
            },
            isSamplingEnabled: true
        )
        
        let result = sampler.sampleSpans(items: spans)
        
        #expect(result.count == 1)
        #expect(originalSpan.attributes != result[0].attributes)
        #expect(result[0].spanId == originalSpan.spanId)
        #expect(result[0].traceId == originalSpan.traceId)
        #expect(result[0].parentSpanId == originalSpan.parentSpanId)
        #expect(result[0].instrumentationScope == originalSpan.instrumentationScope)
    }
}


