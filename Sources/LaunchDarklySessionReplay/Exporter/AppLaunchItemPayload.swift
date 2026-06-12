import Foundation
import LaunchDarklyObservability

/// The `event.*` data carried on an app-launch breadcrumb, encoded as the
/// custom-event payload. Mirrors the web `Identify`/`Track` stringified-JSON shape.
struct AppLaunchPayload: Codable {
    var launchType: String?
    var version: String?
    var build: String?
    var previousVersion: String?

    enum CodingKeys: String, CodingKey {
        case launchType = "launch_type"
        case version
        case build
        case previousVersion = "previous_version"
    }
}

/// Session-replay queue item for an app-launch breadcrumb (`Launch`), sourced from
/// the observability app-launch stream. Mirrors `AppLifecycleItemPayload`.
struct AppLaunchItemPayload: EventQueueItemPayload {
    let tag: CustomDataTag
    let payload: AppLaunchPayload
    var timestamp: TimeInterval
    let sessionId: String

    var exporterClass: AnyClass {
        SessionReplayExporter.self
    }

    func cost() -> Int {
        100
    }
}

extension AppLaunchItemPayload {
    init(signal: AppLaunchSignal, sessionId: String) {
        self.tag = .appLaunch
        self.payload = AppLaunchPayload(
            launchType: signal.launchType.rawValue,
            version: signal.version,
            build: signal.build,
            previousVersion: signal.previousVersion
        )
        self.timestamp = signal.timestamp
        self.sessionId = sessionId
    }
}
