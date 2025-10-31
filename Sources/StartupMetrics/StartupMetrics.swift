import Foundation

@objcMembers
public final class AppStartTime: NSObject {
    public struct AppStartStats {
        public let startTime: TimeInterval
        public let startDate: Date
    }
    /// Captures uptime when initialized.
    public static var startTime: TimeInterval = {
        let t = ProcessInfo.processInfo.systemUptime
        return t
    }()
    
    /// Captures uptime when initialized.
    public static var stats: AppStartStats = {
        let t = ProcessInfo.processInfo.systemUptime
        let d = Date()

        return .init(startTime: t, startDate: d)
    }()
}

// Expose a function Swift can call from C
@_silgen_name("SwiftStartupMetricsInitialize")
public func SwiftStartupMetricsInitialize() {
    _ = AppStartTime.stats
    _ = AppStartTime.startTime
}
