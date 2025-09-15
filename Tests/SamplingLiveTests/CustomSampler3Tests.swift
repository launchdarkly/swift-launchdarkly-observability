import Testing

@testable import OpenTelemetrySdk
import OpenTelemetryApi

import Common
import Sampling
@testable import SamplingLive

struct CustomSampler3Tests {
    // MARK: - Spans
    
    @Test("should not match when event attributes do not match")
    func shouldNotMatchWhenEventAttributesDoNotMatch() {
        let config = SamplingConfig(
            spans: [
                .init(
                    events: [
                        .init(
                            attributes: [
                                .init(
                                    key: .basic(value: .string("error.type")),
                                    attribute: .basic(value: .string("database"))
                                )
                            ]
                        )
                    ],
                    samplingRatio: 85
                )
            ]
        )
        let customSampler = ExportSampler.customSampler { $0 == 85 }
        customSampler.setConfig(config)
        
        let eventAttributes = [
            "error.type": AttributeValue.string("network"),
            "error.code": AttributeValue.int(503)
        ]
        let event = makeMockSpanEvent(name: "error-event", attributes: eventAttributes)
        let span = makeMockSpanData(
            name: "api-request",
            events: [event]
        )
        
        let result = customSampler.sampleSpan(span)
        
        #expect(result.sample)
        #expect(nil == result.attributes)
    }
    
    @Test("should handle complex matching with multiple criteria")
    func shouldHandleComplexMatchingWithMultipleCriteria() {
        let config = SamplingConfig(
            spans: [
                .init(
                    name: .regex(expression: "complex-span-\\d+"), /// Matches "complex-span-" followed by one or more digits.
                    attributes: [
                        .init(
                            key: .basic(value: .string("http.method")),
                            attribute: .basic(value: .string("POST"))
                        ),
                        .init(
                            key: .regex(expression: "http\\.status.*"), /// Matches any string starting with "http.status" followed by zero or more characters.
                            attribute: .basic(value: .int(500))
                        )
                    ],
                    samplingRatio: 50
                )
            ]
        )
        let customSampler = ExportSampler.customSampler { $0 == 50 }
        customSampler.setConfig(config)
        let attributes = [
            "http.method": AttributeValue.string("POST"),
            "http.status_code": AttributeValue.int(500),
            "url": AttributeValue.string("https://api.example.com/users"),
            "retry": AttributeValue.bool(true)
        ]
        let span = makeMockSpanData(
            name: "complex-span-123",
            attributes: attributes
        )
        
        let result = customSampler.sampleSpan(span)
        
        #expect(result.sample)
        #expect(.int(50) == result.attributes?[LDSemanticAttribute.ATTR_SAMPLING_RATIO])
    }
}
