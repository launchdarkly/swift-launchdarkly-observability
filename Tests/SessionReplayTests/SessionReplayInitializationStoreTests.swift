import Foundation
import Testing
@testable import LaunchDarklySessionReplay

@Suite("SessionReplayInitializationStore")
struct SessionReplayInitializationStoreTests {

    private func makeDefaults() -> (UserDefaults, () -> Void) {
        let suiteName = "com.launchdarkly.observability.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (defaults, { UserDefaults().removePersistentDomain(forName: suiteName) })
    }

    @Test("No failure is stored by default")
    func noFailureByDefault() {
        let (defaults, cleanUp) = makeDefaults()
        defer { cleanUp() }

        let store = SessionReplayInitializationStore(sdkKey: "mob-key", defaults: defaults)
        #expect(store.loadFailure() == nil)
    }

    @Test("Stored failure survives a new store for the same environment")
    func failureRoundTrips() {
        let (defaults, cleanUp) = makeDefaults()
        defer { cleanUp() }

        SessionReplayInitializationStore(sdkKey: "mob-key", defaults: defaults)
            .store(reason: "SESSION_REPLAY_BLOCKED_IN_REGION", timestamp: 42)

        let failure = SessionReplayInitializationStore(sdkKey: "mob-key", defaults: defaults).loadFailure()
        #expect(failure?.reason == "SESSION_REPLAY_BLOCKED_IN_REGION")
        #expect(failure?.timestamp == 42)
    }

    @Test("Failure from another environment is ignored")
    func failureIsScopedToEnvironment() {
        let (defaults, cleanUp) = makeDefaults()
        defer { cleanUp() }

        SessionReplayInitializationStore(sdkKey: "mob-staging", defaults: defaults)
            .store(reason: "unauthorized")

        #expect(SessionReplayInitializationStore(sdkKey: "mob-production", defaults: defaults).loadFailure() == nil)
        #expect(SessionReplayInitializationStore(sdkKey: "mob-staging", defaults: defaults).loadFailure() != nil)
    }

    @Test("Clearing removes the stored failure")
    func clearingRemovesFailure() {
        let (defaults, cleanUp) = makeDefaults()
        defer { cleanUp() }

        let store = SessionReplayInitializationStore(sdkKey: "mob-key", defaults: defaults)
        store.store(reason: "unauthorized")
        store.clearFailure()

        #expect(store.loadFailure() == nil)
    }

    @Test("Long reasons are truncated")
    func longReasonsAreTruncated() {
        let (defaults, cleanUp) = makeDefaults()
        defer { cleanUp() }

        let store = SessionReplayInitializationStore(sdkKey: "mob-key", defaults: defaults)
        store.store(reason: String(repeating: "x", count: SessionReplayInitializationStore.maxReasonLength * 3))

        #expect(store.loadFailure()?.reason.count == SessionReplayInitializationStore.maxReasonLength)
    }

    @Test("The SDK key is never written to disk")
    func sdkKeyIsNotPersisted() throws {
        let (defaults, cleanUp) = makeDefaults()
        defer { cleanUp() }

        SessionReplayInitializationStore(sdkKey: "mob-secret-key", defaults: defaults).store(reason: "unauthorized")

        let data = try #require(defaults.data(forKey: SessionReplayInitializationStore.failureKey))
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("mob-secret-key") == false)
    }
}
