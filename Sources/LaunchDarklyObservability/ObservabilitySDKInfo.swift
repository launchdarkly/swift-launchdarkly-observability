import Foundation
#if os(watchOS)
    import WatchKit
#elseif !os(macOS)
    import UIKit
#endif

/// Shared SDK metadata for HTTP clients and diagnostics.
public final class ObservabilitySDKInfo {
    private init() {}

    public static func userAgent() -> String {
#if os(iOS)
    return "iOS" // Temporary value for inactivity forwarding
#else
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(osVersion.majorVersion).\(osVersion.minorVersion)"
#if os(macOS)
            let deviceName = "Mac"
            let osName = "macOS"
        #elseif os(watchOS)
            let deviceName = "Apple Watch"
            let osName = "watchOS"
        #else
            let deviceName = UIDevice.current.model
            let osName = UIDevice.current.systemName
        #endif

        return "Swift-Observability/\(sdkVersion) (\(deviceName); \(osName) \(versionString)) Gecko/20100101 \(osName)"
#endif
    }
}
