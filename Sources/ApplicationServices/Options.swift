import Foundation
import OSLog
//public init(
//    name: String = "observability-sdk"
//) {
//    self.log = OSLog(subsystem: "com.launchdarkly", category: name)
//}
///
/// Configuration options for the Observability plugin.
///
///   - serviceName The service name for the application. Defaults to the app package name if not set.
///   - serviceVersion The version of the service. Defaults to the app version if not set.
///   - otlpEndpoint The OTLP exporter endpoint. Defaults to LaunchDarkly endpoint.
///   - backendUrl The backend URL for non-OTLP operations. Defaults to LaunchDarkly url.
///   - resourceAttributes Additional resource attributes to include in telemetry data.
///   - customHeaders Custom headers to include with OTLP exports.
///   - sessionBackgroundTimeout Session timeout if app is backgrounded. Defaults to 15 minutes. 15 * 60
///   - isDebug Enables verbose telemetry logging if true as well as other debug functionality. Defaults to false.
///   - disableErrorTracking Disables error tracking if true. Defaults to false.
///   - disableLogs Disables logs if true. Defaults to false.
///   - disableTraces Disables traces if true. Defaults to false.
///   - disableMetrics Disables metrics if true. Defaults to false.
///   - logAdapter The log adapter to use. Defaults to using the LaunchDarkly SDK's LDTimberLogging.adapter(). ///Use LDAndroidLogging.adapter() to use the Android logging adapter.
///   - loggerName The name of the logger to use. Defaults to "LaunchDarklyObservabilityPlugin".
///

public struct Options {
    public enum FeatureFlag {
        case enabled
        case disabled
    }
    public let serviceName: String
    public let serviceVersion: String
    public let otlpEndpoint: String
    public let backendUrl: String
    public let resourceAttributes: [String: AttributeValue]
    public let customHeaders: [(String, String)]
    public let sessionBackgroundTimeout: TimeInterval
    public let isDebug: Bool
    public let disableErrorTracking: Bool
    public let logs: FeatureFlag
    public let traces: FeatureFlag
    public let metrics: FeatureFlag
    public let log: OSLog
    
    public init(
        serviceName: String = "observability-swift",
        serviceVersion: String = "0.1.0",
        otlpEndpoint: String = "https://otel.observability.app.launchdarkly.com:4318",
        backendUrl: String = "https://pub.observability.app.launchdarkly.com",
        resourceAttributes: [String: AttributeValue] = [:],
        customHeaders: [(String, String)] = [],
        sessionBackgroundTimeout: TimeInterval = 15 * 60,
        isDebug: Bool = false,
        disableErrorTracking: Bool = false,
        logs: FeatureFlag = .enabled,
        traces: FeatureFlag = .enabled,
        metrics: FeatureFlag = .enabled,
        log: OSLog = OSLog(subsystem: "com.launchdarkly", category: "LaunchDarklyObservabilityPlugin")
    ) {
        self.serviceName = serviceName
        self.serviceVersion = serviceVersion
        self.otlpEndpoint = otlpEndpoint
        self.backendUrl = backendUrl
        self.resourceAttributes = resourceAttributes
        self.customHeaders = customHeaders
        self.sessionBackgroundTimeout = sessionBackgroundTimeout
        self.isDebug = isDebug
        self.disableErrorTracking = disableErrorTracking
        self.logs = logs
        self.traces = traces
        self.metrics = metrics
        self.log = log
    }
}
