import Foundation.NSURLError
import Testing
@testable import Observability

struct MetricsApiClientTests {
    @Test("Metrics API disabled")
    func metricsDisabled() throws {
        let apiSpy = MetricsApiSpy()
        var options = Options()
        
        let metric = Metric(name: "test", value: 0.0, attributes: [:])
        options.metricsApi = .disabled
        let sut = AppMetricsClient(
            options: options.metricsApi,
            metricsApiClient: apiSpy
        )
                
        sut.recordMetric(metric: metric)
        sut.recordCount(metric: metric)
        sut.recordIncr(metric: metric)
        sut.recordHistogram(metric: metric)
        sut.recordUpDownCounter(metric: metric)
        
        for invokeCount in apiSpy.invokeCount.values {
            #expect(invokeCount == 0)
        }
    }
    
    @Test("Metrics API enabled")
    func metricsEnabled() throws {
        let apiSpy = MetricsApiSpy()
        var options = Options()
        
        let metric = Metric(name: "test", value: 0.0, attributes: [:])
        options.metricsApi = .enabled
        let sut = AppMetricsClient(
            options: options.metricsApi,
            metricsApiClient: apiSpy
        )
        
        sut.recordMetric(metric: metric)
        sut.recordCount(metric: metric)
        sut.recordIncr(metric: metric)
        sut.recordHistogram(metric: metric)
        sut.recordUpDownCounter(metric: metric)
        
        
        var count = 0
        for invokeCount in apiSpy.invokeCount.values {
            #expect(invokeCount == 1)
            count += 1
        }
        
        #expect(count == MetricsApiSpy.Instrument.allCases.count)
    }
}

final class MetricsApiSpy: MetricsApi {
    enum Instrument: Hashable, CaseIterable {
        case gauge, counter, increment, histogram, upDownCounter
    }
    var invokeCount = [
        Instrument.gauge: 0,
        .counter: 0,
        .increment: 0,
        .histogram: 0,
        .upDownCounter: 0
    ]
    
    func recordMetric(metric: Metric) { invokeCount[.gauge]! += 1 }
    func recordCount(metric: Metric) { invokeCount[.counter]! += 1 }
    func recordIncr(metric: Metric) { invokeCount[.increment]! += 1 }
    func recordHistogram(metric: Metric) { invokeCount[.histogram]! += 1 }
    func recordUpDownCounter(metric: Metric) { invokeCount[.upDownCounter]! += 1 }
}
