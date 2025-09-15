import Testing

@testable import OpenTelemetrySdk
import OpenTelemetryApi

import Common
import Sampling
@testable import SamplingLive

struct SampleSpansParentRelationship {
    @Test("should remove child and grandchild spans when parent is not sampled")
    func shouldRemoveChildAndGrandchildSpansWhenParentIsNotSampled() {
        let sampler = ExportSampler.fake(
            sampleSpan: { span in
                if span.name == "parent" {
                    return .init(sample: false)
                } else {
                    return .init(sample: true)
                }
            },
            isSamplingEnabled: true
        )
        
        let parentSpan = makeMockSpanData(name: "parent")
        let childSpan = makeMockSpanData(name: "child", parentSpanId: parentSpan.spanId)
        let grandchildSpan = makeMockSpanData(name: "grandchild", parentSpanId: childSpan.spanId)
        let unrelatedSpan = makeMockSpanData(name: "unrelated")
        
        let spans = [parentSpan, childSpan, grandchildSpan, unrelatedSpan]
        
        let result = sampler.sampleSpans(items: spans)
        
        #expect(result.count == 1)
        #expect(result[0] == unrelatedSpan)
    }
    
    @Test("should keep child spans when parent is sampled")
    func shouldKeepChildSpansWhenParentIsSampled() {
        let sampler = ExportSampler.fake(
            sampleSpan: { span in
                return .init(sample: true)
            },
            isSamplingEnabled: true
        )
        
        let parentSpan = makeMockSpanData(name: "parent")
        let childSpan1 = makeMockSpanData(name: "child1", parentSpanId: parentSpan.spanId)
        let childSpan2 = makeMockSpanData(name: "child2", parentSpanId: parentSpan.spanId)
        
        let spans = [parentSpan, childSpan1, childSpan2]
        
        let result = sampler.sampleSpans(items: spans)
        
        #expect(result.count == 3)
        #expect(result.allSatisfy { spans.contains($0) })
    }
    
    @Test("should remove child spans even if parent is sampled but child is not")
    func shouldRemoveChildSpansEvenIfParentIsSampledButChildIsNot() {
        let sampler = ExportSampler.fake(
            sampleSpan: { span in
                if span.name == "child" {
                    return .init(sample: false)
                } else {
                    return .init(sample: true)
                }
            },
            isSamplingEnabled: true
        )
        
        let parentSpan = makeMockSpanData(name: "parent")
        let childSpan = makeMockSpanData(name: "child", parentSpanId: parentSpan.spanId)
        let grandchildSpan = makeMockSpanData(name: "grandchild", parentSpanId: childSpan.spanId)
        
        let spans = [parentSpan, childSpan, grandchildSpan]
        
        let result = sampler.sampleSpans(items: spans)
        
        #expect(result.count == 1)
        #expect(result[0] == parentSpan)
    }
    
    @Test("should handle complex span hierarchy with mixed sampling")
    func shouldHandleComplexSpanHierarchyWithMixedSampling() {
        /*
         Create a complex hierarchy:
         parent1 (sampled) -> child1 (not sampled) -> grandchild1 (sampled)
         parent2 (not sampled) -> child2 (sampled) -> grandchild2 (sampled)
         unrelated (sampled)
         */
     
        let sampler = ExportSampler.fake(
            sampleSpan: { span in
                if ["parent1", "grandchild1", "child2", "grandchild2", "unrelated"].contains(span.name) {
                    return .init(sample: true)
                } else if ["child1", "parent2"].contains(span.name) {
                    return .init(sample: false)
                } else {
                    return .init(sample: false)
                }
            },
            isSamplingEnabled: true
        )
        
        let parent1 = makeMockSpanData(name: "parent1")
        let child1 = makeMockSpanData(name: "child1", parentSpanId: parent1.spanId)
        let grandchild1 = makeMockSpanData(name: "grandchild1", parentSpanId: child1.spanId)
        
        let parent2 = makeMockSpanData(name: "parent2")
        let child2 = makeMockSpanData(name: "child2", parentSpanId: parent2.spanId)
        let grandchild2 = makeMockSpanData(name: "grandchild2", parentSpanId: child2.spanId)
        
        let unrelated = makeMockSpanData(name: "unrelated")
        
        let spans = [parent1, child1, grandchild1, parent2, child2, grandchild2, unrelated]
        
        let result = sampler.sampleSpans(items: spans)
        
        #expect(result.count == 2)
        #expect(result.contains(parent1))
        #expect(result.contains(unrelated))
    }
}
