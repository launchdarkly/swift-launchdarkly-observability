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
        
#if os(iOS)
        return "Mozilla/5.0 (\(deviceName); \(osName) \(versionString)) Gecko/20100101 iOS/\(sdkVersion)" // Temporary value for inactivity forwarding
#else
        return "Mozilla/5.0 (\(deviceName); \(osName) \(versionString)) Gecko/20100101 Swift-Observability/\(sdkVersion)"
#endif
    }
}
