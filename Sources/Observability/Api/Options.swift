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
    public enum LogsAPIOptions: Int, Comparable, CustomStringConvertible, CaseIterable {
        case
        `none`,
        trace,
        trace2,
        trace3,
        trace4,
        debug,
        debug2,
        debug3,
        debug4,
        info,
        info2,
        info3,
        info4,
        warn,
        warn2,
        warn3,
        warn4,
        error,
        error2,
        error3,
        error4,
        fatal,
        fatal2,
        fatal3,
        fatal4
        
        public var description: String {
            switch self {
            case .trace:
                return "TRACE"
            case .trace2:
                return "TRACE2"
            case .trace3:
                return "TRACE3"
            case .trace4:
                return "TRACE4"
            case .debug:
                return "DEBUG"
            case .debug2:
                return "DEBUG2"
            case .debug3:
                return "DEBUG3"
            case .debug4:
                return "DEBUG4"
            case .info:
                return "INFO"
            case .info2:
                return "INFO2"
            case .info3:
                return "INFO3"
            case .info4:
                return "INFO4"
            case .warn:
                return "WARN"
            case .warn2:
                return "WARN2"
            case .warn3:
                return "WARN3"
            case .warn4:
                return "WARN4"
            case .error:
                return "ERROR"
            case .error2:
                return "ERROR2"
            case .error3:
                return "ERROR3"
            case .error4:
                return "ERROR4"
            case .fatal:
                return "FATAL"
            case .fatal2:
                return "FATAL2"
            case .fatal3:
                return "FATAL3"
            case .fatal4:
                return "FATAL4"
            case .none:
                return "NONE"
            }
        }
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    public struct TracingAPIOptions {
        public static var enabled: Self {
            .init()
        }
        
        public static var disabled: Self {
            .init(includeErrors: false, includeSpans: false)
        }
        
        public init(includeErrors: Bool = true, includeSpans: Bool = true) {
            self.includeErrors = includeErrors
            self.includeSpans = includeSpans
        }
        var includeErrors = true
        var includeSpans = true
    }
    public enum MetricsAPIOptions {
        case enabled, disabled
    }
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
        case memoryWarnings
        case cpu
        case launchTimes
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
    public var logsApiLevel: LogsAPIOptions
    public var metricsApi: MetricsAPIOptions
    public var tracesApi: TracingAPIOptions
    public var log: OSLog
    public var crashReporting: FeatureFlag
    public var autoInstrumentation: Set<AutoInstrumented>
    let launchMeter = LaunchMeter()
    
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
        logsApiLevel: LogsAPIOptions = .info,
        tracesApi: TracingAPIOptions = .enabled,
        metricsApi: MetricsAPIOptions = .enabled,
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
        self.logsApiLevel = logsApiLevel
        self.tracesApi = tracesApi
        self.metricsApi = metricsApi
        self.log = log
        self.crashReporting = crashReporting
        self.autoInstrumentation = autoInstrumentation
    }
}
