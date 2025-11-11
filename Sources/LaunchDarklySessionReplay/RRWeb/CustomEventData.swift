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
