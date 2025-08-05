import Testing
import OpenTelemetrySdk
import OpenTelemetryApi
import LaunchDarklyObservability

struct ObservabilityClientTests {
    let sut = ObservabilityClient(
        configuration: Configuration(
            otlpEndpoint: "http://127.0.0.1:4318",
            isDebug: true
        )
    )
    
    @Test func tracer() async throws {
        let span = sut
            .spanBuilder(spanName: "Push: details")
            .setSpanKind(spanKind: .client)
            .startSpan()
        defer { span.end() }
        let random = Int.random(in: 1..<10)
        
        try await wait(for: 1)
        
        #expect(random > 0)
    }
}
