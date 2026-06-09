import Foundation
import LaunchDarklyObservability

/// The `event.*` data carried on an app-lifecycle breadcrumb, encoded as the
/// custom-event payload. Optional fields are omitted when absent.
struct AppLifecyclePayload: Codable {
    var lifecycleState: String?

    enum CodingKeys: String, CodingKey {
        case lifecycleState = "lifecycle_state"
    }
}

/// Session-replay queue item for an app-lifecycle breadcrumb (`Foreground`,
/// `Background`), sourced from the observability app-lifecycle stream. Mirrors
/// `NavigateItemPayload`/`TrackItemPayload`.
struct AppLifecycleItemPayload: EventQueueItemPayload {
    let tag: CustomDataTag
    let payload: AppLifecyclePayload
    var timestamp: TimeInterval
    let sessionId: String

    var exporterClass: AnyClass {
        SessionReplayExporter.self
    }

    func cost() -> Int {
        100
    }
}

extension AppLifecycleItemPayload {
    init(signal: AppLifecycleSignal, sessionId: String) {
        switch signal.kind {
        case .foreground:
            self.tag = .appForeground
        case .background:
            self.tag = .appBackground
        }
        self.payload = AppLifecyclePayload(lifecycleState: signal.lifecycleState)
        self.timestamp = signal.timestamp
        self.sessionId = sessionId
    }
}
