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

struct IdentityPayload: Codable {
//    var userIdentifier: String
//    var telemetrySdkName: String
//    var telemetrySdkVersion: String
//    var featureFlagSetId: String
//    var featureFlagProviderName: String
    var user: String
    var key: String
 //   var canonicalKey: String
    
    enum CodingKeys: String, CodingKey {
//        case userIdentifier
//        case telemetrySdkName = "telemetry.sdk.name"
//        case telemetrySdkVersion = "telemetry.sdk.version"
//        case featureFlagSetId = "feature_flag.set.id"
//        case featureFlagProviderName = "feature_flag.provider.name"
        case user
        case key
//        case canonicalKey
    }
}
