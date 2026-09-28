#if LD_COCOAPODS
import LaunchDarklyObservability
#else
import LaunchDarklyOtel
#endif
import Foundation

/// Crash reporting backed by KSCrash, symbolicated from uploaded dSYMs.
///
/// Select it with ``LaunchDarklyOtel/ObservabilityOptions/CrashReporting/ksCrash``. KSCrash
/// installs process-wide signal and exception handlers, so don't enable it alongside another
/// crash reporter.
public struct KSCrashProvider: CrashReportingProvider {
    public init() {}

    public func install(options: ObservabilityOptions) throws {
        try KSCrashReportService.install()
    }

    public func makeCrashReporting(runtime: ObservabilityRuntime) throws -> CrashReporting {
        try KSCrashReportService(logsApi: runtime.logs, log: runtime.options.log)
    }
}

extension ObservabilityOptions.CrashReporting {
    /// Crash reporting backed by KSCrash. See ``KSCrashProvider``.
    public static var ksCrash: Self {
        .init(source: .provider(KSCrashProvider()))
    }
}
