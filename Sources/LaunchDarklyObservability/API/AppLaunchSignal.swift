import Foundation

/// An app-launch analytics event broadcast to in-process consumers such as
/// Session Replay.
///
/// Drives both the taxonomy span (`app_launch`) and the Session Replay timeline
/// breadcrumb (`Launch`). Emitted once per process launch. Mirrors
/// ``AppLifecycleSignal``.
public struct AppLaunchSignal: Sendable, Equatable {
    /// The product-milestone of the launch (taxonomy `event.launch_type`). This is
    /// orthogonal to the cold/warm startup-performance dimension carried by ``startType``.
    public enum LaunchType: String, Sendable {
        /// A normal launch (the stored app version matches the current one).
        case relaunch
        /// First launch after a fresh install (no previously stored version).
        case install
        /// First launch after a version change.
        case update
        /// The current app version could not be read, so the launch milestone is
        /// indeterminable (nothing is persisted, so it can't be compared across launches).
        case unknown
    }

    /// The cold/warm startup-performance dimension (taxonomy `app.start` span event).
    public enum StartType: String, Sendable {
        case cold
        case warm
    }

    public let launchType: LaunchType
    /// Current app version (`CFBundleShortVersionString`).
    public let version: String?
    /// Current build number (`CFBundleVersion`).
    public let build: String?
    /// Version before an `update` launch; `nil` otherwise.
    public let previousVersion: String?
    /// Cold vs warm process start, when known.
    public let startType: StartType?
    /// Time from process start to launch detection, in milliseconds, when known.
    public let startDurationMs: Double?
    /// Event time, in seconds since 1970.
    public let timestamp: TimeInterval

    public init(
        launchType: LaunchType,
        version: String? = nil,
        build: String? = nil,
        previousVersion: String? = nil,
        startType: StartType? = nil,
        startDurationMs: Double? = nil,
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.launchType = launchType
        self.version = version
        self.build = build
        self.previousVersion = previousVersion
        self.startType = startType
        self.startDurationMs = startDurationMs
        self.timestamp = timestamp
    }
}
