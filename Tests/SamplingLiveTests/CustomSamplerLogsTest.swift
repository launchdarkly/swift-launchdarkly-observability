import Testing

@testable import OpenTelemetrySdk
import OpenTelemetryApi

import Common
import Sampling
@testable import SamplingLive

struct CustomSamplerLogsTest {
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
        #expect(.int(42) == result.attributes?[LDSemanticAttribute.attribute_sampling_ratio])
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
        #expect(.int(42) == result.attributes?[LDSemanticAttribute.attribute_sampling_ratio])
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
        #expect(.int(42) == result.attributes?[LDSemanticAttribute.attribute_sampling_ratio])
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
            "service.name": AttributeValue.string("api-gateway"),
            "environment": AttributeValue.string("production")
        ]
        let log = makeMockReadableLogRecord(attributes: attributes)
        
        let result = customSampler.sampleLog(log)
        
        #expect(result.sample)
        #expect(.int(75) == result.attributes?[LDSemanticAttribute.attribute_sampling_ratio])
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
            "service.name": AttributeValue.string("db-connector"),
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
        #expect(.int(90) == result.attributes?[LDSemanticAttribute.attribute_sampling_ratio])
    }
}
