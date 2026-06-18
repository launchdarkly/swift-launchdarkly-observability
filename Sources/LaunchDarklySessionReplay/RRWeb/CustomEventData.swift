import Foundation

struct CustomEventData<PayloadType: Codable>: EventDataProtocol {
    var tag: CustomDataTag
    var payload: PayloadType
}

struct ViewportPayload: Codable {
    var width: Int
    var height: Int
    var availWidth: Int
    var availHeight: Int
    var colorDepth: Int
    var pixelDepth: Int
    var orientation: Int
}

struct ClickPayload: Codable {
    var clickTarget: String
    var clickTextContent: String
    var clickSelector: String
    /// Stable id of the screen active when the click happened (`event.screen_id` analog), stamped
    /// onto the interaction at tap time from the shared `ScreenStack`. Matches the id carried by the
    /// OpenTelemetry `click` span and manual `trackClick`, so replay clicks correlate to the same
    /// screen. Omitted when unknown.
    var screenId: String?
    /// Human-readable name of the screen active when the click happened (`event.screen_name`
    /// analog), stamped onto the interaction at tap time from the shared `ScreenStack`. Omitted when
    /// unknown.
    var screenName: String?
}

/// Mirrors the web `Track` custom-event payload (`{ ...metadata, event }`) emitted by
/// `RecordSDK.track` -> `addCustomEvent('Track', stringify(...))`.
struct TrackPayload: Codable {
    var event: String
    var value: Double?
    var data: [String: String]
}

/// Unified wire payload for `CustomDataTag.press` (`"Press"`).
/// `source` discriminates input origin: `"remote"`, `"physical-keyboard"`, or `"software-keyboard"`.
/// `pressType` and `pressTypeSystemRaw` are only set when `source == "remote"`.
struct PressPayload: Codable, Equatable {
    var source: String
    var pressType: String?
    var pressTypeSystemRaw: Int?
    var target: String?
}
