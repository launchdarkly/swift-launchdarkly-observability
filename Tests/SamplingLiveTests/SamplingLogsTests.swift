import Testing

@testable import OpenTelemetrySdk
import OpenTelemetryApi

import Common
import Sampling
@testable import SamplingLive

struct SamplingLogsTests {
    @Test func threadSafeSampler() {
        let sampler = ThreadSafeSampler.shared
        
        #expect(sampler.sample(1) == true)
        #expect(sampler.sample(0) == false)
    }
    
    @Test("Given a list of logs, when sampling is disabled, then exporter should return all logs")
    func disablingSampling() {
        let sampler = ExportSampler.fake(isSamplingEnabled: false)
        let logs = (1...3).map { makeMockReadableLogRecord(body: .string("log\($0)")) }
        
        let result = sampleLogs(items: logs, sampler: sampler)
        
        #expect(logs.count == result.count)
        
        for (r, l) in zip(result, logs) {
            #expect(r.body == l.body)
        }
    }
    
    @Test("Given a empty list of logs, when sampling is enabled, then exporter should return empty result")
    func enablingSampling() {
        let sampler = ExportSampler.fake(isSamplingEnabled: true)
        
        let result = sampleLogs(items: [], sampler: sampler)
        
        #expect(result.isEmpty)
    }
    
    @Test("Given a list of logs, when sampling is enabled and no logs are sampled, then should return empty")
    func enablingNoLogsSampled() {
        let sampler = ExportSampler.fake(
            sampleLog: { _ in .init(sample: false) },
            isSamplingEnabled: true
        )
        let logs = (1...3).map { makeMockReadableLogRecord(body: .string("log\($0)")) }
        
        let result = sampleLogs(items: logs, sampler: sampler)
        
        #expect(result.isEmpty)
    }
    
    @Test(
        """
        Given a list of logs without additional attributes,
        when sampling is enabled and all logs are sampled, then should return all
        """
    )
    func enablingAllLogsSampledWithoutAdditionalAttributes() {
        let sampler = ExportSampler.fake(
            sampleLog: { _ in .init(sample: true, attributes: nil) },
            isSamplingEnabled: true
        )
        let logs = (1...3).map { makeMockReadableLogRecord(body: .string("log\($0)")) }
        
        let result = sampleLogs(items: logs, sampler: sampler)
        
        #expect(logs.count == result.count)
        
        for (r, l) in zip(result, logs) {
            #expect(r.body == l.body)
        }
    }
    
    @Test("Given a list of logs, when sampling is enabled, then should return only sampled ones")
    func enablingSamplingSomeAreSampled() {
        let lowerBound = 1
        let upperBound = 4
        let logs = (lowerBound...upperBound).map { makeMockReadableLogRecord(body: .string("log\($0)")) }
        
        let sampler = ExportSampler.fake(
            sampleLog: { logData in
                if logData.body == logs[2].body {
                    return .init(sample: false)
                } else {
                    return .init(sample: true)
                }
            },
            isSamplingEnabled: true
        )
        
        
        let result = sampleLogs(items: logs, sampler: sampler)
        
        
        let logAtIndex2ThatIsNotSampledIsInTheArray = { (log: ReadableLogRecord) -> Bool in
            log.body == logs[2].body
        }
        #expect(result.count == logs.count - 1)

        #expect(result.contains(where: logAtIndex2ThatIsNotSampledIsInTheArray) == false)
    }
    
    @Test("Given a log with attributes, when sampling is enabled and sampling attributes is provided, then should add sampling attributes and preserve the original ones")
    func enablingSamplingProvidingSamplingAttributes() {
        let originalAttributes = [
            "service.name": AttributeValue.string("api-service"),
            "environment": AttributeValue.string("production")
        ]
        let samplingAttributes = [
            LDSemanticAttribute.ATTR_SAMPLING_RATIO:  AttributeValue.int(42)
        ]
        let mockLog = makeMockReadableLogRecord(body: .string("test-log"), attributes: originalAttributes)
        let sampler = ExportSampler.fake(
            sampleLog: { logData in
                if let logBody = logData.body, case AttributeValue.string(let body) = logBody, body == "test-log" {
                    return .init(sample: true, attributes: samplingAttributes)
                } else {
                    return .init(sample: false)
                }
            },
            isSamplingEnabled: true
        )
        
        // When
        let items = [mockLog]
        let result = sampleLogs(items: items, sampler: sampler)
        #expect(result.count == items.count)
        
        #expect(result[0].attributes["service.name"] == originalAttributes["service.name"])
        #expect(result[0].attributes["environment"] == originalAttributes["environment"])
        #expect(result[0].attributes[LDSemanticAttribute.ATTR_SAMPLING_RATIO] == samplingAttributes[LDSemanticAttribute.ATTR_SAMPLING_RATIO])
    }
    
    @Test("Given a set of logs, when having a mixed sampling results with and without attributes, then should handle them correctly")
    func mixedLogsSamplingResults() {
        let lowerBound = 1
        let upperBound = 4
        let logs = (lowerBound...upperBound).map { makeMockReadableLogRecord(body: .string("log\($0)")) }
        
        let samplingAttributes = [
            LDSemanticAttribute.ATTR_SAMPLING_RATIO:  AttributeValue.int(50)
        ]
        
        let sampler = ExportSampler.fake(
            sampleLog: { logData in
                if logData.body == logs[0].body {
                    return .init(sample: true, attributes: nil)
                } else if logData.body == logs[2].body {
                    return .init(sample: true, attributes: samplingAttributes)
                } else {
                    return .init(sample: false)
                }
            },
            isSamplingEnabled: true
        )
        
        let result = sampleLogs(items: logs, sampler: sampler)
        
        let sampled = [logs[0], logs[2]]
        #expect(result.count == sampled.count)
        
        #expect(result[0].body == logs[0].body)
        #expect(result[0].attributes == logs[0].attributes)
        
        #expect(result[1].body == logs[2].body)
        #expect(result[1].attributes != logs[2].attributes) // result[1] has modified attributes with sampling attr. added
        #expect(result[1].attributes[LDSemanticAttribute.ATTR_SAMPLING_RATIO] == AttributeValue.int(50))
    }
}
