import Testing

@testable import OpenTelemetrySdk
import OpenTelemetryApi
@testable import Observability

extension OpenTelemetryApi.AttributeValue: @retroactive ExpressibleByExtendedGraphemeClusterLiteral {}
extension OpenTelemetryApi.AttributeValue: @retroactive ExpressibleByUnicodeScalarLiteral {}
extension OpenTelemetryApi.AttributeValue: @retroactive ExpressibleByStringLiteral {
    
    public init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }
}

struct CustomSamplerTests {
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
        #expect(result.attributes?[SemanticConvention.attributeSamplingRatio] == .int(10))
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
        #expect(result.attributes?[SemanticConvention.attributeSamplingRatio] == .int(42))
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
        #expect(.int(42) == result.attributes?[SemanticConvention.attributeSamplingRatio])
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
        #expect(.int(75) == result.attributes?[SemanticConvention.attributeSamplingRatio])
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
        #expect(.int(100) == result.attributes?[SemanticConvention.attributeSamplingRatio])
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
        #expect(.int(42) == result.attributes?[SemanticConvention.attributeSamplingRatio])
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
            "error.type": OpenTelemetryApi.AttributeValue.string("network"),
            "error.code": AttributeValue.int(503)
        ]
        let event = makeMockSpanEvent(name: "error-event", attributes: eventAttributes)
        let span = makeMockSpanData(
            name: "api-request",
            events: [event]
        )
        
        let result = customSampler.sampleSpan(span)
        
        #expect(result.sample)
        #expect(.int(85) == result.attributes?[SemanticConvention.attributeSamplingRatio])
    }
    
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
            "error.type": OpenTelemetryApi.AttributeValue.string("network"),
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
            "http.method": OpenTelemetryApi.AttributeValue.string("POST"),
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
        #expect(.int(50) == result.attributes?[SemanticConvention.attributeSamplingRatio])
    }
    
    // MARK: - Logs
    
    @Test("should match log based on severity")
    func shouldMatchLogBasedOnSeverity() {
        let config = SamplingConfig(
            logs: [
                .init(
                    severityText: .basic(value: .string("ERROR")),
                    samplingRatio: 42
                )
            ]
        )
        
        let customSampler = ExportSampler.customSampler { $0 == 42 }
        customSampler.setConfig(config)
        let log = makeMockReadableLogRecord(severity: .error)
        
        let result = customSampler.sampleLog(log)
        
        #expect(result.sample)
        #expect(.int(42) == result.attributes?[SemanticConvention.attributeSamplingRatio])
    }
    
    @Test("should not match log when severity does not match")
    func shouldNotMatchLogWhenSeverityDoesNotMatch() {
        let config = SamplingConfig(
            logs: [
                .init(
                    severityText: .basic(value: .string("ERROR")),
                    samplingRatio: 42
                )
            ]
        )
        
        let customSampler = ExportSampler.customSampler { $0 == 42 }
        customSampler.setConfig(config)
        let log = makeMockReadableLogRecord(severity: .info)
        
        let result = customSampler.sampleLog(log)
        
        #expect(result.sample)
        #expect(nil == result.attributes)
    }
    
    @Test("should match log based on message with exact value")
    func shouldMatchLogBasedOnMessageWithExactValue() {
        let config = SamplingConfig(
            logs: [
                .init(
                    message: .basic(value: "Connection failed"),
                    samplingRatio: 42
                )
            ]
        )
        
        let customSampler = ExportSampler.customSampler { $0 == 42 }
        customSampler.setConfig(config)
        let log = makeMockReadableLogRecord(body: .string("Connection failed"))
        
        let result = customSampler.sampleLog(log)
        
        #expect(result.sample)
        #expect(.int(42) == result.attributes?[SemanticConvention.attributeSamplingRatio])
    }
    
    @Test("should match log based on message with regex")
    func shouldMatchLogBasedOnMessageWithRegex() {
        let config = SamplingConfig(
            logs: [
                .init(
                    message: .regex(expression: "Error: .*"), /// Matches any string that starts with "Error:" followed by any characters
                    samplingRatio: 42
                )
            ]
        )
        
        let customSampler = ExportSampler.customSampler { $0 == 42 }
        customSampler.setConfig(config)
        let log = makeMockReadableLogRecord(body: .string("Error: Connection timed out"))
        
        let result = customSampler.sampleLog(log)
        
        #expect(result.sample)
        #expect(.int(42) == result.attributes?[SemanticConvention.attributeSamplingRatio])
    }
    
    @Test("should match log based on string attribute value")
    func shouldMatchLogBasedOnStringAttributeValue() {
        let config = SamplingConfig(
            logs: [
                .init(
                    attributes: [
                        .init(
                            key: .basic(value: "service.name"),
                            attribute: .basic(value: "api-gateway")
                        )
                    ],
                    samplingRatio: 75
                )
            ]
        )
        
        let customSampler = ExportSampler.customSampler { $0 == 75 }
        customSampler.setConfig(config)
        let attributes = [
            "service.name": OpenTelemetryApi.AttributeValue.string("api-gateway"),
            "environment": AttributeValue.string("production")
        ]
        let log = makeMockReadableLogRecord(attributes: attributes)
        
        let result = customSampler.sampleLog(log)
        
        #expect(result.sample)
        #expect(.int(75) == result.attributes?[SemanticConvention.attributeSamplingRatio])
    }
    
    @Test("should not match log when attributes do not exist")
    func shouldNotMatchLogWhenAttributesDoNotExist() {
        let config = SamplingConfig(
            logs: [
                .init(
                    attributes: [
                        .init(
                            key: .basic(value: "service.name"),
                            attribute: .basic(value: "api-gateway")
                        )
                    ],
                    samplingRatio: 75
                )
            ]
        )
        
        let customSampler = ExportSampler.customSampler { $0 == 75 }
        customSampler.setConfig(config)
        let log = makeMockReadableLogRecord(body: .string("Connection failed"))
        
        let result = customSampler.sampleLog(log)
        
        #expect(result.sample)
        #expect(nil == result.attributes)
    }
    
    @Test("should handle complex log matching with multiple criteria")
    func shouldHandleComplexLogMatchingWithMultipleCriteria() {
        let config = SamplingConfig(
            logs: [
                .init(
                    message: .regex(expression: "Database connection .*"),
                    severityText: .basic(value: "ERROR"),
                    attributes: [
                        .init(
                            key: .regex(expression: "service.*"),
                            attribute: .regex(expression: "db-.*")
                        ),
                        .init(
                            key: .basic(value: "retry.enabled"),
                            attribute: .basic(value: .bool(true))
                        )
                    ],
                    samplingRatio: 90
                )
            ]
        )
        
        let customSampler = ExportSampler.customSampler { $0 == 90 }
        customSampler.setConfig(config)
        let attributes = [
            "service.name": OpenTelemetryApi.AttributeValue.string("db-connector"),
            "retry.enabled": AttributeValue.bool(true),
            "retry.count": AttributeValue.int(3)
        ]
        let log = makeMockReadableLogRecord(
            body: .string("Database connection failed: timeout"),
            severity: .error,
            attributes: attributes
        )
        
        let result = customSampler.sampleLog(log)
        
        #expect(result.sample)
        #expect(.int(90) == result.attributes?[SemanticConvention.attributeSamplingRatio])
    }
}
