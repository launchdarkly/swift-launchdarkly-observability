import Testing

@testable import OpenTelemetrySdk
import OpenTelemetryApi

import Common
import Sampling
@testable import SamplingLive


struct CustomSampler2Tests {
    // MARK: - Spans
    
    @Test("should return true for isSamplingEnabled when config has spans and logs")
    func shouldReturnTrueForIsSamplingEnabledWhenConfigHasSpansAndLogs() {
        let config = SamplingConfig(
            spans: [
                .init(samplingRatio: 10)
            ],
            logs: [
                .init(samplingRatio: 20)
            ]
        )
        let customSampler = ExportSampler.customSampler()
        customSampler.setConfig(config)
        
        #expect(customSampler.isSamplingEnabled())
    }
    
    
    @Test("should return true for isSamplingEnabled when config has spans")
    func shouldReturnTrueForIsSamplingEnabledWhenConfigHasSpans() {
        let config = SamplingConfig(
            spans: [
                .init(samplingRatio: 10)
            ]
        )
        let customSampler = ExportSampler.customSampler()
        customSampler.setConfig(config)
        
        #expect(customSampler.isSamplingEnabled())
    }
    
    @Test("should return true for isSamplingEnabled when config has logs")
    func shouldReturnTrueForIsSamplingEnabledWhenConfigHasLogs() {
        let config = SamplingConfig(
            logs: [
                .init(samplingRatio: 20)
            ]
        )
        let customSampler = ExportSampler.customSampler()
        customSampler.setConfig(config)
        
        #expect(customSampler.isSamplingEnabled())
    }
    
    @Test("should return false for isSamplingEnabled when config is null")
    func shouldReturnFalseForIsSamplingEnabledWhenConfigIsNull() {
        
        let customSampler = ExportSampler.customSampler()
        customSampler.setConfig(nil)
        
        #expect(customSampler.isSamplingEnabled() == false)
    }
    
    @Test("should return false for isSamplingEnabled when config has no spans or logs")
    func shouldReturnFalseForIsSamplingEnabledWhenConfigHasNoSpansOrLogs() {
        let config = SamplingConfig()
        let customSampler = ExportSampler.customSampler()
        customSampler.setConfig(config)
        
        #expect(customSampler.isSamplingEnabled() == false)
    }
    
    @Test("should match span when no match criteria is specified")
    func shouldMatchSpanWhenNoMatchCriteriaIsSpecified() {
        let config = SamplingConfig(
            spans: [
                .init(samplingRatio: 10)
            ]
        )
        
        
        let customSampler = ExportSampler.customSampler { !($0 == 10) }
        customSampler.setConfig(config)
        
        let span = makeMockSpanData(name: "test-span", attributes: [:])
        
        let result = customSampler.sampleSpan(span)
        
        #expect(result.sample == false)
        #expect(result.attributes?[LDSemanticAttribute.ATTR_SAMPLING_RATIO] == .int(10))
    }
    
    @Test("should match span when no config is specified")
    func shouldMatchSpanWhenNoConfigIsSpecified() {
        let span = makeMockSpanData(name: "test-span", attributes: [:])
        let customSampler = ExportSampler.customSampler { !($0 == 10) }
        
        let result = customSampler.sampleSpan(span)
        
        #expect(result.sample)
        #expect(result.attributes == nil)
    }
    
    @Test("should match span based on exact name")
    func shouldMatchSpanBasedOnExactName() {
        let config = SamplingConfig(
            spans: [
                .init(
                    name: .basic(value: .string("test-span")),
                    samplingRatio: 42
                )
            ]
        )
        let customSampler = ExportSampler.customSampler { $0 == 42 }
        customSampler.setConfig(config)
        let span = makeMockSpanData(name: "test-span")
        
        let result = customSampler.sampleSpan(span)
        
        #expect(result.sample)
        #expect(result.attributes?[LDSemanticAttribute.ATTR_SAMPLING_RATIO] == .int(42))
    }
    
    @Test("should not match span when name does not match")
    func shouldNotMatchSpanWhenNameDoesNotMatch() {
        let config = SamplingConfig(
            spans: [
                .init(
                    name: .basic(value: .string("test-span")),
                    samplingRatio: 42
                )
            ]
        )
        let customSampler = ExportSampler.customSampler { $0 == 42 }
        customSampler.setConfig(config)
        let span = makeMockSpanData(name: "other-span")
        
        let result = customSampler.sampleSpan(span)
        
        #expect(result.sample)
        #expect(result.attributes == nil)
    }
    
    @Test("should match span based on regex name")
    func shouldMatchSpanBasedOnRegexName() {
        let config = SamplingConfig(
            spans: [
                .init(
                    name: .regex(expression: "test-span-\\d+"), /// Matches "test-span-" followed by one or more digits.
                    samplingRatio: 42
                )
            ]
        )
        let customSampler = ExportSampler.customSampler { $0 == 42 }
        customSampler.setConfig(config)
        let span = makeMockSpanData(name: "test-span-123")
        
        let result = customSampler.sampleSpan(span)
        
        #expect(result.sample)
        #expect(.int(42) == result.attributes?[LDSemanticAttribute.ATTR_SAMPLING_RATIO])
    }
    
    @Test("should match span based on string attribute value")
    func shouldMatchSpanBasedOnStringAttributeValue() {
        let config = SamplingConfig(
            spans: [
                .init(
                    attributes: [
                        .init(
                            key: .basic(value: .string("http.method")),
                            attribute: .basic(value: .string("POST"))
                        )
                    ],
                    samplingRatio: 75
                )
            ]
        )
        let customSampler = ExportSampler.customSampler { $0 == 75 }
        customSampler.setConfig(config)
        let span = makeMockSpanData(
            name: "test-span-123",
            attributes: [
                "http.method": .string("POST"),
                "http.url": .string("https://api.example.com/data")
            ]
        )
        
        let result = customSampler.sampleSpan(span)
        
        #expect(result.sample)
        #expect(.int(75) == result.attributes?[LDSemanticAttribute.ATTR_SAMPLING_RATIO])
    }
    
    @Test("should match span based on numeric attribute value")
    func shouldMatchSpanBasedOnNumericAttributeValue() {
        let config = SamplingConfig(
            spans: [
                .init(
                    attributes: [
                        .init(
                            key: .basic(value: .string("http.status_code")),
                            attribute: .basic(value: .int(500))
                        )
                    ],
                    samplingRatio: 100
                )
            ]
        )
        let customSampler = ExportSampler.customSampler { $0 == 100 }
        customSampler.setConfig(config)
        
        
        let span = makeMockSpanData(
            name: "http-response",
            attributes: [
                "http.status_code": .int(500),
                "http.method": .string("POST")
            ]
        )
        
        let result = customSampler.sampleSpan(span)
        
        #expect(result.sample)
        #expect(.int(100) == result.attributes?[LDSemanticAttribute.ATTR_SAMPLING_RATIO])
    }
    
    @Test("should match span based on event name")
    func shouldMatchSpanBasedOnEventName() {
        let config = SamplingConfig(
            spans: [
                .init(
                    events: [
                        .init(name: .basic(value: .string("test-event")))
                    ],
                    samplingRatio: 42
                )
            ]
        )
        let customSampler = ExportSampler.customSampler { $0 == 42 }
        customSampler.setConfig(config)
        let event = makeMockSpanEvent(name: "test-event")
        let span = makeMockSpanData(
            name: "test-span-123",
            events: [event]
        )
        
        let result = customSampler.sampleSpan(span)
        
        #expect(result.sample)
        #expect(.int(42) == result.attributes?[LDSemanticAttribute.ATTR_SAMPLING_RATIO])
    }
    
    @Test("should match span based on event attributes")
    func shouldmatchSpanBasedOnEventAttributes() {
        let config = SamplingConfig(
            spans: [
                .init(
                    events: [
                        .init(
                            attributes: [
                                .init(
                                    key: .basic(value: .string("error.type")),
                                    attribute: .basic(value: .string("network"))
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
        #expect(.int(85) == result.attributes?[LDSemanticAttribute.ATTR_SAMPLING_RATIO])
    }
}






