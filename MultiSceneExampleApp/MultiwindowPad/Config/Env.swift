import Foundation

/// Values from `TestAppShared/Secrets.xcconfig`, surfaced through Info.plist.
/// Copy `Secrets.xcconfig.example` to `Secrets.xcconfig` and fill in the mobile key.
struct Env {
    private static let secrets = Bundle.main.infoDictionary ?? [:]

    static var mobileKey: String {
        guard let key = secrets["mobileKey"] as? String, !key.isEmpty else {
            fatalError("Missing mobileKey in Info.plist. See TestAppShared/Secrets.xcconfig.example.")
        }
        return key
    }

    /// `nil` or empty falls back to the SDK's default endpoint.
    static var otlpEndpoint: String? {
        secrets["otlpEndpoint"] as? String
    }

    /// `nil` or empty falls back to the SDK's default backend.
    static var backendUrl: String? {
        secrets["backendUrl"] as? String
    }
}
