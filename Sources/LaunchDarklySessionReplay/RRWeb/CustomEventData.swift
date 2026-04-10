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
