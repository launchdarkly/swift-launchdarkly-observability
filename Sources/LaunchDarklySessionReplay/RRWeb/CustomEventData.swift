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
/// `target` is the view class name; `textContent` matches ``ClickPayload.clickTextContent`` (typically accessibility identifier). `inputDevice` is a coarse category (e.g. `siriRemote`, `unknown`).
struct RemoteControlPayload: Codable, Equatable {
    var pressType: String
    var pressTypeSystemRaw: Int?
    var target: String
    var textContent: String
    var inputDevice: String

    enum CodingKeys: String, CodingKey {
        case pressType
        case pressTypeSystemRaw
        case target
        case textContent
        case inputDevice
    }

    init(
        pressType: String,
        pressTypeSystemRaw: Int? = nil,
        target: String = "",
        textContent: String = "",
        inputDevice: String = ""
    ) {
        self.pressType = pressType
        self.pressTypeSystemRaw = pressTypeSystemRaw
        self.target = target
        self.textContent = textContent
        self.inputDevice = inputDevice
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pressType = try c.decode(String.self, forKey: .pressType)
        pressTypeSystemRaw = try c.decodeIfPresent(Int.self, forKey: .pressTypeSystemRaw)
        target = try c.decodeIfPresent(String.self, forKey: .target) ?? ""
        textContent = try c.decodeIfPresent(String.self, forKey: .textContent) ?? ""
        inputDevice = try c.decodeIfPresent(String.self, forKey: .inputDevice) ?? ""
    }
}

/// Wire payload when the custom event tag is `Keyboard` (`CustomDataTag.keyboardPress.rawValue`). `target` is the view class name; no key identifiers or typed text.
struct KeyboardPressPayload: Codable, Equatable {
    var target: String

    enum CodingKeys: String, CodingKey {
        case target
    }

    init(target: String = "") {
        self.target = target
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        target = try c.decodeIfPresent(String.self, forKey: .target) ?? ""
    }
}
