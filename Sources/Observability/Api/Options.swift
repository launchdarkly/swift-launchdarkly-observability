import Foundation
import OSLog
@_exported import OpenTelemetryApi
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
    public enum TracingOriginsOption {
        case enabled([String])
        case enabledRegex([String])
        case disabled
    }
    public enum AutoInstrumented {
        case urlSession
        case userTaps
        case memory
        case cpu
    }
    public var serviceName: String
    public var serviceVersion: String
    public var otlpEndpoint: String
    public var backendUrl: String
    public var resourceAttributes: [String: AttributeValue]
    public var customHeaders: [String: String]
    public var tracingOrigins: TracingOriginsOption
    public var urlBlocklist: [String]
    public var sessionBackgroundTimeout: TimeInterval
    public var isDebug: Bool
    public var disableErrorTracking: Bool
    public var logs: FeatureFlag
    public var traces: FeatureFlag
    public var metrics: FeatureFlag
    public var log: OSLog
    public var crashReporting: FeatureFlag
    public var autoInstrumentation: Set<AutoInstrumented>
    
    public init(
        serviceName: String = "observability-swift",
        serviceVersion: String = "0.1.0",
        otlpEndpoint: String = "https://otel.observability.app.launchdarkly.com:4318",
        backendUrl: String = "https://pub.observability.app.launchdarkly.com",
        resourceAttributes: [String: AttributeValue] = [:],
        customHeaders: [String: String] = [:],
        tracingOrigins: TracingOriginsOption = .disabled,
        urlBlocklist: [String] = [],
        sessionBackgroundTimeout: TimeInterval = 15 * 60,
        isDebug: Bool = false,
        disableErrorTracking: Bool = false,
        logs: FeatureFlag = .enabled,
        traces: FeatureFlag = .enabled,
        metrics: FeatureFlag = .enabled,
        log: OSLog = OSLog(subsystem: "com.launchdarkly", category: "LaunchDarklyObservabilityPlugin"),
        crashReporting: FeatureFlag = .enabled,
        autoInstrumentation: Set<AutoInstrumented> = [.urlSession]
    ) {
        self.serviceName = serviceName
        self.serviceVersion = serviceVersion
        self.otlpEndpoint = otlpEndpoint
        self.backendUrl = backendUrl
        self.resourceAttributes = resourceAttributes
        self.customHeaders = customHeaders
        self.tracingOrigins = tracingOrigins
        self.urlBlocklist = urlBlocklist
        self.sessionBackgroundTimeout = sessionBackgroundTimeout
        self.isDebug = isDebug
        self.disableErrorTracking = disableErrorTracking
        self.logs = logs
        self.traces = traces
        self.metrics = metrics
        self.log = log
        self.crashReporting = crashReporting
        self.autoInstrumentation = autoInstrumentation
    }
}
