import Foundation
import OSLog
@_exported import OpenTelemetryApi

/// Configuration options for the LaunchDarkly Observability plugin.
///
/// Pass an instance to the plugin at initialisation to control the OTLP exporter
/// endpoint, telemetry levels, automatic instrumentation, and crash reporting.
public struct ObservabilityOptions {
    public enum Defaults {
        public static let otlpEndpoint = "https://otel.observability.app.launchdarkly.com:4318"
        public static let backendUrl = "https://pub.observability.app.launchdarkly.com"
    }

    public enum LogLevel: Int, Comparable, CustomStringConvertible, CaseIterable {
        case
        trace = 1,
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
        fatal4,
        `none`
        
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
    public struct AppTracing {
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
    public enum AppMetrics {
        case enabled, disabled
    }
    public enum CrashReportingSource {
        case KSCrash
        case metricKit
        case none
    }
    public struct CrashReporting {
        public let source: CrashReportingSource
        public static var enabled: Self {
            .init()
        }
        
        public init(source: CrashReportingSource = .KSCrash) {
            self.source = source
        }
    }
    public enum FeatureFlag {
        case enabled
        case disabled
        
        var isEnabled: Bool {
            switch self {
            case .enabled: return true
            case .disabled: return false
            }
        }
    }
    public enum TracingOriginsOption {
        case enabled([String])
        case enabledRegex([String])
        case disabled
    }
    public struct Instrumentation {
        let urlSession: FeatureFlag
        let userTaps: FeatureFlag
        let memory: FeatureFlag
        let memoryWarnings: FeatureFlag
        let cpu: FeatureFlag
        let launchTimes: FeatureFlag
        
        public init(
            urlSession: FeatureFlag = .disabled,
            userTaps: FeatureFlag = .disabled,
            memory: FeatureFlag = .disabled,
            memoryWarnings: FeatureFlag = .disabled,
            cpu: FeatureFlag = .disabled,
            launchTimes: FeatureFlag = .disabled
        ) {
            self.urlSession = urlSession
            self.userTaps = userTaps
            self.memory = memory
            self.memoryWarnings = memoryWarnings
            self.cpu = cpu
            self.launchTimes = launchTimes
        }
    }
    public var isEnabled: Bool
    public var serviceName: String
    public var serviceVersion: String
    public var otlpEndpoint: String
    public var backendUrl: String
    public var contextFriendlyName: String?
    public var resourceAttributes: [String: AttributeValue]
    public var customHeaders: [String: String]
    public var tracingOrigins: TracingOriginsOption
    public var urlBlocklist: [String]
    public var sessionBackgroundTimeout: TimeInterval
    public var isDebug: Bool
    public var logsApiLevel: LogLevel
    public var metricsApi: AppMetrics
    public var tracesApi: AppTracing
    public var log: OSLog
    public var crashReporting: CrashReporting
    public var instrumentation: Instrumentation
    
    /// Creates a configuration for the Observability plugin.
    ///
    /// - Parameters:
    ///   - isEnabled: Whether the plugin emits telemetry. When `false` the plugin is installed
    ///     but no logs, traces, or metrics are exported. Defaults to `true`.
    ///   - serviceName: The OpenTelemetry `service.name` attribute reported with every signal.
    ///     Defaults to `"observability-swift"`.
    ///   - serviceVersion: The OpenTelemetry `service.version` attribute reported with every
    ///     signal. Defaults to `"0.1.0"`.
    ///   - otlpEndpoint: The OTLP/HTTP exporter endpoint. `nil` or an empty string falls back
    ///     to ``Defaults/otlpEndpoint``.
    ///   - backendUrl: The backend URL used for non-OTLP operations (e.g. session metadata).
    ///     `nil` or an empty string falls back to ``Defaults/backendUrl``.
    ///   - contextFriendlyName: An optional human-readable name attached to the LaunchDarkly
    ///     context for this session. Defaults to `nil`.
    ///   - resourceAttributes: Additional OpenTelemetry resource attributes merged into every
    ///     signal. Defaults to an empty dictionary.
    ///   - customHeaders: Extra HTTP headers added to OTLP exports (e.g. for proxies or auth).
    ///     Defaults to an empty dictionary.
    ///   - tracingOrigins: Which outgoing request origins should propagate distributed tracing
    ///     headers. Defaults to ``TracingOriginsOption/disabled``.
    ///   - urlBlocklist: URL patterns to exclude from automatic URLSession instrumentation.
    ///     Defaults to an empty array.
    ///   - sessionBackgroundTimeout: How long the app may stay in the background before the
    ///     current session is ended. Defaults to 15 minutes.
    ///   - isDebug: Enables verbose internal logging and other debug behaviour. Defaults to
    ///     `false`.
    ///   - logsApiLevel: Minimum severity of logs forwarded to the OpenTelemetry logs pipeline.
    ///     Use ``LogLevel/none`` to disable logs entirely. Defaults to ``LogLevel/info``.
    ///   - tracesApi: Controls automatic trace generation (errors and spans). Use
    ///     ``AppTracing/disabled`` to turn tracing off. Defaults to ``AppTracing/enabled``.
    ///   - metricsApi: Controls metric export. Use ``AppMetrics/disabled`` to turn metrics
    ///     off. Defaults to ``AppMetrics/enabled``.
    ///   - log: The `OSLog` used for the plugin's own diagnostic output. Defaults to a logger
    ///     under subsystem `"com.launchdarkly"` and category `"LaunchDarklyObservabilityPlugin"`.
    ///   - crashReporting: Crash-reporting configuration, including which provider to use
    ///     (KSCrash or MetricKit). Defaults to ``CrashReporting/enabled`` (KSCrash).
    ///   - instrumentation: Per-feature toggles for automatic instrumentation (URLSession,
    ///     user taps, memory, CPU, launch times, …). Defaults to all features disabled.
    public init(
        isEnabled: Bool = true,
        serviceName: String = "observability-swift",
        serviceVersion: String = "0.1.0",
        otlpEndpoint: String? = nil,
        backendUrl: String? = nil,
        contextFriendlyName: String? = nil,
        resourceAttributes: [String: AttributeValue] = [:],
        customHeaders: [String: String] = [:],
        tracingOrigins: TracingOriginsOption = .disabled,
        urlBlocklist: [String] = [],
        sessionBackgroundTimeout: TimeInterval = 15 * 60,
        isDebug: Bool = false,
        logsApiLevel: LogLevel = .info,
        tracesApi: AppTracing = .enabled,
        metricsApi: AppMetrics = .enabled,
        log: OSLog = OSLog(subsystem: "com.launchdarkly", category: "LaunchDarklyObservabilityPlugin"),
        crashReporting: CrashReporting = .enabled,
        instrumentation: Instrumentation = .init()
    ) {
        self.serviceName = serviceName
        self.serviceVersion = serviceVersion
        self.otlpEndpoint = otlpEndpoint.flatMap { $0.isEmpty ? nil : $0 } ?? Defaults.otlpEndpoint
        self.backendUrl = backendUrl.flatMap { $0.isEmpty ? nil : $0 } ?? Defaults.backendUrl
        self.contextFriendlyName = contextFriendlyName
        self.resourceAttributes = resourceAttributes
        self.customHeaders = customHeaders
        self.tracingOrigins = tracingOrigins
        self.urlBlocklist = urlBlocklist
        self.sessionBackgroundTimeout = sessionBackgroundTimeout
        self.isDebug = isDebug
        self.logsApiLevel = logsApiLevel
        self.tracesApi = tracesApi
        self.metricsApi = metricsApi
        self.log = log
        self.crashReporting = crashReporting
        self.instrumentation = instrumentation
        self.isEnabled = isEnabled
    }
}

