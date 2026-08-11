import Testing
import Foundation
@testable import LaunchDarklyOtel
@testable import LaunchDarklyObservability

/// Guards the separation that lets `LaunchDarklyOtel` run beside another observability SDK:
/// the pipeline installs nothing into the host app by itself, and everything that hooks the
/// process arrives through an ``ObservabilityInstrumenting``.
///
/// Endpoints point at an unroutable host so constructing the service can't reach the network.
struct PipelineIsolationTests {
    private func makeOptions() -> ObservabilityOptions {
        ObservabilityOptions(
            otlpEndpoint: "http://127.0.0.1:1",
            backendUrl: "http://127.0.0.1:1"
        )
    }

    @Test("a pipeline with no instrumentation provider attaches no host-app hooks")
    func pipelineWithoutProviderInstallsNothing() throws {
        let service = try ObservabilityService(
            options: makeOptions(),
            mobileKey: "test-key",
            sessionAttributes: [:]
        )

        let context = try #require(service.context)
        #expect(context.userInteractionManager == nil)
        #expect(context.appLaunchSignal == nil)
    }

    @Test("the default provider attaches the touch pipeline and resolves the launch signal")
    func defaultProviderAttachesInstrumentation() throws {
        let service = try ObservabilityService(
            options: makeOptions(),
            mobileKey: "test-key",
            sessionAttributes: [:]
        )
        service.install(
            instrumenting: DefaultInstrumentation(),
            appStartEndUptime: ProcessInfo.processInfo.systemUptime
        )

        let context = try #require(service.context)
        #expect(context.userInteractionManager != nil)
        #expect(context.appLaunchSignal != nil)
    }

    @Test("attaching the touch pipeline does not start capturing on its own")
    func attachedTouchPipelineStaysInert() throws {
        let service = try ObservabilityService(
            options: makeOptions(),
            mobileKey: "test-key",
            sessionAttributes: [:]
        )
        service.install(
            instrumenting: DefaultInstrumentation(),
            appStartEndUptime: ProcessInfo.processInfo.systemUptime
        )

        // The manager is handed to Session Replay at construction, so it exists well before
        // anything should be capturing. The swizzle must wait for an explicit `start()`.
        let manager = try #require(service.context?.userInteractions)
        #expect(manager.isCapturing == false)
    }
}
