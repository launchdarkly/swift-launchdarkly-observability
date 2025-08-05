import Testing
import Instrumentation
import OpenTelemetrySdk
import OpenTelemetryApi

struct MeterTests {
    let sut = MeterFacade(
        configuration: .init(
            otlpEndpoint: "http://127.0.0.1:4318",
            isDebug: true
        )
    )
    @Test func example() async throws {
        let counter = sut.meter.createIntCounter(name: "test counter")
        let labels = ["dim1": "value1"]
        for _ in 0..<1000 {
            counter.add(value: 1, labels: labels)
        }
        
        try await wait(for: 3)
    }
}
