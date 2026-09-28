import Testing
import Foundation
@testable import LaunchDarklyOtel
@testable import LaunchDarklyObservability

/// Endpoints point at an unroutable host so constructing the service can't reach the network.
struct CrashReportingProviderTests {
    private struct TestError: Error {}

    private final class RecordingReporter: CrashReporting {
        var deliveries = 0
        func logPendingCrashReports() { deliveries += 1 }
    }

    private final class RecordingProvider: CrashReportingProvider {
        let reporter = RecordingReporter()
        var installs = 0
        var failsToStart = false

        func install(options: ObservabilityOptions) throws { installs += 1 }

        func makeCrashReporting(runtime: ObservabilityRuntime) throws -> CrashReporting {
            if failsToStart { throw TestError() }
            return reporter
        }
    }

    private func makeOptions(_ crashReporting: ObservabilityOptions.CrashReporting) -> ObservabilityOptions {
        ObservabilityOptions(
            otlpEndpoint: "http://127.0.0.1:1",
            backendUrl: "http://127.0.0.1:1",
            crashReporting: crashReporting
        )
    }

    @Test("crash reporting is off by default")
    func disabledByDefault() {
        let options = ObservabilityOptions()
        guard case .none = options.crashReporting.source else {
            Issue.record("expected crash reporting to be disabled by default")
            return
        }
    }

    @Test("the default instrumentation hands the pipeline the provider's reporter")
    func usesProviderReporter() throws {
        let provider = RecordingProvider()
        let service = try ObservabilityService(
            options: makeOptions(.init(source: .provider(provider))),
            mobileKey: "test-key",
            sessionAttributes: [:]
        )

        let reporting = DefaultInstrumentation().makeCrashReporting(runtime: service)

        #expect(reporting as? RecordingReporter === provider.reporter)
    }

    @Test("a provider that fails to start leaves crash reporting off")
    func failingProviderDisablesCrashReporting() throws {
        let provider = RecordingProvider()
        provider.failsToStart = true
        let service = try ObservabilityService(
            options: makeOptions(.init(source: .provider(provider))),
            mobileKey: "test-key",
            sessionAttributes: [:]
        )

        let reporting = DefaultInstrumentation().makeCrashReporting(runtime: service)

        #expect(reporting == nil)
        #expect(provider.reporter.deliveries == 0)
    }

    @Test("the Observability plugin installs the provider's crash handlers")
    func pluginInstallsProvider() {
        let provider = RecordingProvider()

        _ = Observability(options: makeOptions(.init(source: .provider(provider))))

        #expect(provider.installs == 1)
    }
}
