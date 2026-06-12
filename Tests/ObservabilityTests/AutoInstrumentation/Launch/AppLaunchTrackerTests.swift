#if canImport(UIKit)
import Foundation
import Testing
@testable import LaunchDarklyObservability

@Suite
struct AppVersionStoreTests {

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppVersionStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test
    func firstLaunchIsInstall() {
        let store = AppVersionStore(defaults: makeDefaults())
        let result = store.resolveAndPersist(currentVersion: "1.0.0")
        #expect(result.launchType == .install)
        #expect(result.previousVersion == nil)
    }

    @Test
    func sameVersionIsRelaunch() {
        let defaults = makeDefaults()
        _ = AppVersionStore(defaults: defaults).resolveAndPersist(currentVersion: "1.0.0")
        let result = AppVersionStore(defaults: defaults).resolveAndPersist(currentVersion: "1.0.0")
        #expect(result.launchType == .relaunch)
        #expect(result.previousVersion == nil)
    }

    @Test
    func changedVersionIsUpdate() {
        let defaults = makeDefaults()
        _ = AppVersionStore(defaults: defaults).resolveAndPersist(currentVersion: "1.0.0")
        let result = AppVersionStore(defaults: defaults).resolveAndPersist(currentVersion: "1.1.0")
        #expect(result.launchType == .update)
        #expect(result.previousVersion == "1.0.0")
    }

    @Test
    func persistsCurrentVersionForNextLaunch() {
        let defaults = makeDefaults()
        _ = AppVersionStore(defaults: defaults).resolveAndPersist(currentVersion: "2.0.0")
        #expect(defaults.string(forKey: AppVersionStore.lastVersionKey) == "2.0.0")
    }

    @Test
    func nilVersionIsUnknown() {
        let store = AppVersionStore(defaults: makeDefaults())
        let result = store.resolveAndPersist(currentVersion: nil)
        #expect(result.launchType == .unknown)
        #expect(result.previousVersion == nil)
    }

    @Test
    func nilVersionDoesNotPersistAndDoesNotClobberStoredVersion() {
        let defaults = makeDefaults()
        _ = AppVersionStore(defaults: defaults).resolveAndPersist(currentVersion: "1.0.0")
        _ = AppVersionStore(defaults: defaults).resolveAndPersist(currentVersion: nil)
        // The unreadable launch must not overwrite the persisted version, so a later readable
        // relaunch is still recognized as a relaunch (not a fresh install).
        #expect(defaults.string(forKey: AppVersionStore.lastVersionKey) == "1.0.0")
        let result = AppVersionStore(defaults: defaults).resolveAndPersist(currentVersion: "1.0.0")
        #expect(result.launchType == .relaunch)
    }
}
#endif
