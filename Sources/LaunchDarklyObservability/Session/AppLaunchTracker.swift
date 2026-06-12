import Foundation

/// Resolves the product-milestone of a launch (`install` / `update` / `relaunch`)
/// by comparing the current app version against the last one persisted in
/// `UserDefaults`. Persists the current version as a side effect so the next launch
/// can be classified.
struct AppVersionStore {
    static let lastVersionKey = "com.launchdarkly.observability.lastAppVersion"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Classifies the launch relative to the stored version, then records `currentVersion`.
    /// - Returns: the resolved launch type and the previous version (only for `update`).
    func resolveAndPersist(currentVersion: String?) -> (launchType: AppLaunchSignal.LaunchType, previousVersion: String?) {
        let stored = defaults.string(forKey: Self.lastVersionKey)
        defer {
            if let currentVersion { defaults.set(currentVersion, forKey: Self.lastVersionKey) }
        }

        guard let stored else {
            return (.install, nil)
        }
        if stored != currentVersion {
            return (.update, stored)
        }
        return (.relaunch, nil)
    }
}

/// Emits a single ``AppLaunchSignal`` per process launch. Resolves the launch type
/// (install/update/relaunch) and the cold/warm startup dimension, then yields once
/// on ``start()``.
///
/// Mirrors ``AppLifecycleTracker``: the signal is yielded unconditionally (so the
/// Session Replay `Launch` breadcrumb always fires); the `app_launch` span is gated
/// separately by `analytics.appLaunch`.
final class AppLaunchTracker: AppLifecycleTracking {
    private let versionStore: AppVersionStore
    private let yield: (AppLaunchSignal) -> Void
    private var hasYielded = false

    init(versionStore: AppVersionStore = AppVersionStore(), yield: @escaping (AppLaunchSignal) -> Void) {
        self.versionStore = versionStore
        self.yield = yield
    }

    func start() {
        guard !hasYielded else { return }
        hasYielded = true
        yield(resolveSignal())
    }

    func stop() {}

    private func resolveSignal() -> AppLaunchSignal {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?[kCFBundleVersionKey as String] as? String

        let (launchType, previousVersion) = versionStore.resolveAndPersist(currentVersion: version)

        // iOS marks prewarmed launches via the `ActivePrewarm` environment flag; treat those as
        // warm starts. The flag is removed after `didFinishLaunching`, so it's captured at load
        // time by `AppStartTime` (read here from that cache, not the live environment).
        let startType: AppLaunchSignal.StartType = AppStartTime.stats.isActivePrewarm ? .warm : .cold
        let startDurationMs = (ProcessInfo.processInfo.systemUptime - AppStartTime.stats.startTime) * 1000.0

        return AppLaunchSignal(
            launchType: launchType,
            version: version,
            build: build,
            previousVersion: previousVersion,
            startType: startType,
            startDurationMs: startDurationMs >= 0 ? startDurationMs : nil
        )
    }
}
