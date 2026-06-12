import Foundation
import OSLog

@objcMembers
public final class AppStartTime: NSObject {
    public struct AppStartStats {
        public let startTime: TimeInterval
        public let startDate: Date
        /// Whether the process was prewarmed by the OS (iOS 15+). The `ActivePrewarm`
        /// environment variable is only present during prewarming and is removed after
        /// `didFinishLaunching`, so it must be captured at load time (this is forced by
        /// the ObjC constructor that calls `SwiftStartupMetricsInitialize`).
        public let isActivePrewarm: Bool
    }
    
    /// Captures uptime when initialized.
    public static var stats: AppStartStats = {
        let t = ProcessInfo.processInfo.systemUptime
        let d = Date()
        let isActivePrewarm = ProcessInfo.processInfo.environment["ActivePrewarm"] == "1"

        return .init(startTime: t, startDate: d, isActivePrewarm: isActivePrewarm)
    }()
}

// Expose a function Swift can call from C
//@_silgen_name("SwiftStartupMetricsInitialize")
@_cdecl("SwiftStartupMetricsInitialize")
public func SwiftStartupMetricsInitialize() {
    _ = AppStartTime.stats
}
