import Foundation

struct CustomEventData<PayloadType: Codable>: EventDataProtocol {
    var tag: String
    var payload: PayloadType
}

struct ViewPortPayload: Codable {
    var width: Int
    var height: Int
    var availWidth: Int
    var availHeight: Int
    var colorDepth: Int
    var pixelDepth: Int
    var orientation: Int
}
