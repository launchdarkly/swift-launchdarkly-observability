import Foundation.NSURLError
import Testing
@testable import Observability

struct TracingApiClientTests {
    @Test("Tracing API disabled")
    func tracingDisabled() throws {
        let apiSpy = TracingApiSpy()
        var options = Options()
        options.tracesApi = .disabled
        let sut = AppTraceClient(
            options: options.tracesApi,
            tracingApiClient: apiSpy
        )
        
        sut.recordError(error: URLError(.badServerResponse), attributes: [:])
        _ = sut.startSpan(name: "span-name", attributes: [:])
        
        #expect(apiSpy.recordErrorInvokeCount == 0)
        #expect(apiSpy.startSpanInvokeCount == 0)
    }
    
    @Test("not include errors, include spans")
    func includeErrorsDisabledIncludeSpansEnabled() throws {
        let apiSpy = TracingApiSpy()
        var options = Options()
        options.tracesApi = .init(includeErrors: false, includeSpans: true)
        let sut = AppTraceClient(
            options: options.tracesApi,
            tracingApiClient: apiSpy
        )
        
        sut.recordError(error: URLError(.badServerResponse), attributes: [:])
        _ = sut.startSpan(name: "span-name", attributes: [:])
        
        #expect(apiSpy.recordErrorInvokeCount == 0)
        #expect(apiSpy.startSpanInvokeCount == 1)
    }
    
    @Test("include include errors, not include spans")
    func includeErrorsDontIncludeSpans() throws {
        let apiSpy = TracingApiSpy()
        var options = Options()
        options.tracesApi = .init(includeErrors: true, includeSpans: false)
        let sut = AppTraceClient(
            options: options.tracesApi,
            tracingApiClient: apiSpy
        )
        
        sut.recordError(error: URLError(.badServerResponse), attributes: [:])
        _ = sut.startSpan(name: "span-name", attributes: [:])
        
        #expect(apiSpy.recordErrorInvokeCount == 1)
        #expect(apiSpy.startSpanInvokeCount == 0)
    }
    
    @Test("Tracing API enabled")
    func tracingEnabled() throws {
        let apiSpy = TracingApiSpy()
        var options = Options()
        options.tracesApi = .enabled
        let sut = AppTraceClient(
            options: options.tracesApi,
            tracingApiClient: apiSpy
        )
        
        sut.recordError(error: URLError(.badServerResponse), attributes: [:])
        _ = sut.startSpan(name: "span-name", attributes: [:])
        
        #expect(apiSpy.recordErrorInvokeCount == 1)
        #expect(apiSpy.startSpanInvokeCount == 1)
    }
}

final class TracingApiSpy: TracesApi {
    var recordErrorInvokeCount = 0
    var startSpanInvokeCount = 0
    func recordError(error: any Error, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        recordErrorInvokeCount += 1
    }
    
    func startSpan(name: String, attributes: [String : OpenTelemetryApi.AttributeValue]) -> any OpenTelemetryApi.Span {
        startSpanInvokeCount += 1
        return OpenTelemetry.instance.tracerProvider
            .get(instrumentationName: "")
            .spanBuilder(spanName: "")
            .startSpan()
    }
}
