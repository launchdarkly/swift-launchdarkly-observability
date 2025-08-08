import Testing
import Instrumentation
import OpenTelemetrySdk
import OpenTelemetryApi

struct LoggerTests {
    let sut = LoggerFacade(
        configuration: .init(
            otlpEndpoint: "http://127.0.0.1:4318",
            isDebug: true
        )
    )
    @Test func example() async throws {
        let eventProvider = sut
            .eventProvider()
            .setSeverity(.debug)
            .setAttributes(["test 1": .int(1)])

        eventProvider.emit()
        
        try await wait(for: 1)
    }
}
