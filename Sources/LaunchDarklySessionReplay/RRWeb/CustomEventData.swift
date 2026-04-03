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

/// Wire payload when the custom event tag is `RemoteControl` (`CustomDataTag.remoteControl.rawValue`).
/// Backend / player: allowlist this tag if ingestion filters; optional `pressTypeSystemRaw` is only set for unmapped `UIPress.PressType` (`pressType` == `other`).
struct RemoteControlPayload: Codable, Equatable {
    var pressType: String
    var pressTypeSystemRaw: Int?
}

/// Wire payload when the custom event tag is `Keyboard` (`CustomDataTag.keyboardPress.rawValue`). No key identifiers or typed text.
struct KeyboardPressPayload: Codable, Equatable {
}
