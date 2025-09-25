import OSLog

public final class ObservabilityLogger {
    public let log: OSLog
    
    public init(
        name: String = "observability-sdk"
    ) {
        self.log = OSLog(subsystem: "com.launchdarkly", category: name)
    }
}
