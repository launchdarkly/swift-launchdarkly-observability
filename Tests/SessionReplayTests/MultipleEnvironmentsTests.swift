import Foundation
import Testing
import LaunchDarkly
@testable import LaunchDarklyOtel
@testable import LaunchDarklySessionReplay

extension SharedStateTests {
    @Suite("Multiple environments")
    struct MultipleEnvironmentsTests {
        private static let primaryKey = "mob-primary"
        // Several secondaries, so that the primary is rarely the first environment the SDK visits.
        private static let secondaryKeys = [
            "secondary-a": "mob-secondary-a",
            "secondary-b": "mob-secondary-b",
            "secondary-c": "mob-secondary-c",
            "secondary-d": "mob-secondary-d",
        ]

        @Test("Observability and Session Replay attach to the primary environment only")
        @MainActor
        func attachToPrimaryOnly() async throws {
            let otel = Otel(options: ObservabilityOptions(
                isEnabled: false,
                otlpEndpoint: "http://127.0.0.1:1",
                backendUrl: "http://127.0.0.1:1"
            ))
            let replay = SessionReplay(options: SessionReplayOptions(isEnabled: false))
            var config = LDConfig(mobileKey: Self.primaryKey, autoEnvAttributes: .disabled)
            config.startOnline = false
            try config.setSecondaryMobileKeys(Self.secondaryKeys)
            config.plugins = [otel, replay]
            let context = try LDContextBuilder(key: "started").build().get()

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                LDClient.start(config: config, context: context, startWaitSeconds: 1) { _ in continuation.resume() }
            }
            defer {
                LDClient.get()?.close()
                LDReplay.shared.client = nil
                LDObserve.shared.client = NoOpObservabilityService.shared
                LDObserve.shared.context = nil
            }

            #expect(LDObserve.shared.context?.sdkKey == Self.primaryKey)
            #expect(replay.sessionReplayService != nil)
            #expect(otel.observabilityHooks[Self.primaryKey]?.delegate != nil)
            #expect(replay.sessionReplayHooks[Self.primaryKey]?.delegate != nil)
            for secondaryKey in Self.secondaryKeys.values {
                #expect(otel.observabilityHooks[secondaryKey] != nil)
                #expect(otel.observabilityHooks[secondaryKey]?.delegate == nil)
                #expect(replay.sessionReplayHooks[secondaryKey] != nil)
                #expect(replay.sessionReplayHooks[secondaryKey]?.delegate == nil)
            }
        }
    }
}
