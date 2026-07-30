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

    @Test("One environment's failure does not displace another's")
    func failuresDoNotOverwriteEachOther() {
        let (defaults, cleanUp) = makeDefaults()
        defer { cleanUp() }

        let staging = SessionReplayInitializationStore(sdkKey: "mob-staging", defaults: defaults)
        let production = SessionReplayInitializationStore(sdkKey: "mob-production", defaults: defaults)

        staging.store(reason: "unauthorized", timestamp: 1)
        production.store(reason: "blocked in region", timestamp: 2)

        #expect(staging.loadFailure()?.reason == "unauthorized")
        #expect(production.loadFailure()?.reason == "blocked in region")

        // Clearing is scoped the same way: recovering in one environment leaves the other withheld.
        production.clearFailure()

        #expect(staging.loadFailure()?.reason == "unauthorized")
        #expect(production.loadFailure() == nil)
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

        let key = SessionReplayInitializationStore.failureKey(for: "mob-secret-key")
        let data = try #require(defaults.data(forKey: key))
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("mob-secret-key") == false)
        // The environment is part of the key name now, so that has to stay a fingerprint too.
        #expect(key.contains("mob-secret-key") == false)
    }
}
