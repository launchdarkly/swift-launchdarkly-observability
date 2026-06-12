import Foundation

/// Resolves the product-milestone of a launch (`install` / `update` / `relaunch`,
/// or `unknown` when the version is unreadable) by comparing the current app version
/// against the last one persisted in `UserDefaults`. Persists the current version as a
/// side effect so the next launch can be classified.
struct AppVersionStore {
    static let lastVersionKey = "com.launchdarkly.observability.lastAppVersion"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Classifies the launch relative to the stored version, then records `currentVersion`.
    /// - Returns: the resolved launch type and the previous version (only for `update`).
    func resolveAndPersist(currentVersion: String?) -> (launchType: AppLaunchSignal.LaunchType, previousVersion: String?) {
        // Without a readable version there is nothing to persist or compare, so the milestone is
        // indeterminable. Returning `.unknown` (rather than `.install`) avoids misclassifying
        // every such relaunch as a fresh install.
        guard let currentVersion else {
            return (.unknown, nil)
        }

        let stored = defaults.string(forKey: Self.lastVersionKey)
        defaults.set(currentVersion, forKey: Self.lastVersionKey)

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
    private let appStartEndUptime: TimeInterval
    private let yield: (AppLaunchSignal) -> Void
    private var hasYielded = false

    /// - Parameter appStartEndUptime: uptime marking the end of the startup window (defaults to
    ///   now). Callers should capture this as early as possible — at SDK entry, before setup work —
    ///   so `start.duration_ms` reflects app startup rather than SDK initialization time.
    init(versionStore: AppVersionStore = AppVersionStore(),
         appStartEndUptime: TimeInterval = ProcessInfo.processInfo.systemUptime,
         yield: @escaping (AppLaunchSignal) -> Void) {
        self.versionStore = versionStore
        self.appStartEndUptime = appStartEndUptime
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
        // Use the SDK-entry uptime (not "now"): resolveSignal runs after the service's setup work,
        // so measuring to now would inflate the startup duration by that setup time.
        let startDurationSeconds = appStartEndUptime - AppStartTime.stats.startTime
        let startDurationMs = startDurationSeconds >= 0 ? startDurationSeconds * 1000.0 : nil

        // Anchor the event time to the end of the measured startup window (process start +
        // duration, i.e. the early SDK-entry point), not to "now". resolveSignal runs after most of
        // observability init, so defaulting the timestamp to now would push the span end and the
        // Session Replay `Launch` placement past the window that `start.duration_ms` deliberately
        // excludes, making span length and breadcrumb placement inconsistent with that metric.
        let timestamp = AppStartTime.stats.startDate
            .addingTimeInterval(max(0, startDurationSeconds))
            .timeIntervalSince1970

        return AppLaunchSignal(
            launchType: launchType,
            version: version,
            build: build,
            previousVersion: previousVersion,
            startType: startType,
            startDurationMs: startDurationMs,
            timestamp: timestamp
        )
    }
}
