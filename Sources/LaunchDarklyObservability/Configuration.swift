import Foundation
@preconcurrency import OpenTelemetryApi

public struct Configuration: Sendable {
    static let otlpTracesEndpoint = "/v1/traces"
    static let otlpLogsEndpoint = "/v1/logs"
    static let otlpMetricsEndpoint = "/v1/metrics"
    /**
     * The service name for the application.
     * @default 'my-swift-app'
     */
    let serviceName: String
    /**
     * The endpoint URL for the OTLP exporter.
     * @default 'https://otel.observability.app.launchdarkly.com:4318'
     */
    let otlpEndpoint: String
    /**
     * The service version for the application.
     * @default '1.0.0'
     */
    let serviceVersion: String
    /**
     * Additional resource attributes to include in telemetry data.
     */
    let resourceAttributes: [String: AttributeValue]
    /**
     * Custom headers to include with OTLP exports.
     */
    let customHeaders: [(String, String)]
    /**
     * Specifies where the backend of the app lives. If specified, the SDK will attach tracing headers to outgoing requests whose destination URLs match a substring or regexp from this list, so that backend errors can be linked back to the session.
     * If 'true' is specified, all requests to the current domain will be matched.
     * @example tracingOrigins: ['localhost', /^\//, 'backend.myapp.com']
     */
    //    let tracingOrigins
    /**
     * A list of URLs to block from tracing.
     * @example urlBlocklist: ['localhost', 'backend.myapp.com']
     */
    let urlBlocklist: [String]?
    /**
     * Session timeout in milliseconds.
     * @default 30 * 60  (30 minutes)
     */
    let sessionTimeout: TimeInterval
    /**
     * Debug mode - enables additional logging.
     * @default false
     */
    let isDebug: Bool
    
    /**
     * Whether errors tracking is disabled.
     */
    let isErrorTrackingDisabled: Bool
    
    /**
     * Whether logs are disabled.
     */
    let isLogsDisabled: Bool
    
    /**
     * Whether traces are disabled.
     */
    let isTracesDisabled: Bool
    
    /**
     * Whether metrics are disabled.
     */
    let isMetricsDisabled: Bool
    
    public init(
        serviceName: String = "App",
        otlpEndpoint: String = "https://otel.observability.app.launchdarkly.com:4318",
        serviceVersion: String = "1.0.0",
        resourceAttributes: [String : AttributeValue] = [:],
        customHeaders: [(String, String)] = [],
        urlBlocklist: [String]? = nil,
        sessionTimeout: TimeInterval = 30 * 60,
        isDebug: Bool = false,
        isErrorTrackingDisabled: Bool = false,
        isLogsDisabled: Bool = false,
        isTracesDisabled: Bool = false,
        isMetricsDisabled: Bool = false
    ) {
        self.serviceName = serviceName
        self.otlpEndpoint = otlpEndpoint
        self.serviceVersion = serviceVersion
        self.resourceAttributes = resourceAttributes
        self.customHeaders = customHeaders
        self.urlBlocklist = urlBlocklist
        self.sessionTimeout = sessionTimeout
        self.isDebug = isDebug
        self.isErrorTrackingDisabled = isErrorTrackingDisabled
        self.isLogsDisabled = isLogsDisabled
        self.isTracesDisabled = isTracesDisabled
        self.isMetricsDisabled = isMetricsDisabled
    }
}
