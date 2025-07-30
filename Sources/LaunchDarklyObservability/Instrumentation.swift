import Foundation
@preconcurrency import OpenTelemetryApi
@preconcurrency import OpenTelemetrySdk
@preconcurrency import OpenTelemetryProtocolExporterHttp
@preconcurrency import StdoutExporter

public protocol Instrumentation: Sendable {
    func start() async
    func updateSession(_ session: Session) async
    func sessionInfo() async -> SessionInfo
    func tracer() async -> Tracer
    func logger() async -> Logger
}

protocol InstrumentationSpan: Sendable {
    func startSpan(name: String, attributes: [String: AttributeValue]?) async -> Span
    func startActiveSpan<T>(
        name: String,
        fn: @Sendable (any SpanBase) async throws -> T,
        attributes: [String: AttributeValue]?
    ) async throws -> T where T: Sendable
}

protocol InstrimentationError: Sendable {
    func recordError(
        _ error: Error,
        attributes: [String: AttributeValue],
        options: Span?
    ) async -> Void
    func recordLog(
        message: String,
        level: Severity,
        attributes: [String: AttributeValue]
    ) async -> Void
}

typealias InstrumentationManager = Instrumentation & InstrumentationSpan & InstrimentationError

public actor DefaultInstrumentation: InstrumentationManager {
    
    private var resource: Resource
    private var configuration: Configuration
    private var session: Session
    
    public init(
        configuration: Configuration = .init(),
        resource: Resource = .init(),
        session: Session
    ) {
        self.resource = resource
        self.configuration = configuration
        self.session = session
    }
    
    public func start() async {
        initializeTracing()
        initializeMetrics()
        initializeLogs()
    }
    
    // MARK: - Session
    
    public func updateSession(_ session: Session) {
        self.session = session
    }
    
    public func sessionInfo() async -> SessionInfo {
        await session.sessionInfo
    }
    
    // MARK: - Tracing
    
    public func tracer() -> Tracer {
        OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: configuration.serviceName,
            instrumentationVersion: configuration.serviceVersion
        )
    }
    
    public func logger() -> Logger {
        OpenTelemetry.instance.loggerProvider.get(
            instrumentationScopeName: configuration.serviceName
        )
    }
    
    public func startSpan(name: String, attributes: [String: AttributeValue]? = nil) async -> Span {
        let span = tracer()
            .spanBuilder(spanName: name)
            .setSpanKind(spanKind: .client)
            .startSpan()
        if let attributes {
            let resourceAttributes = [
                AttributeKey.sessionId.rawValue: AttributeValue.string(await session.sessionId)
            ]
            
            span.setAttributes(attributes.merging(resourceAttributes) { _, new in new })
        }
        return span
    }
    
    func startActiveSpan<T>(
        name: String,
        fn: @Sendable (any OpenTelemetryApi.SpanBase) async throws -> T,
        attributes: [String : OpenTelemetryApi.AttributeValue]?
    ) async throws -> T where T : Sendable {
        try await tracer()
            .spanBuilder(spanName: name)
            .setActive(true)
            .setAttribute(key: AttributeKey.sessionId.rawValue, value: await session.sessionId)
            .withStartedSpan(fn)
    }
    
    // MARK: - Initialize Tracing
    
    func initializeTracing() {
        
        guard let url = URL(string: configuration.otlpEndpoint) else {
            return print("Trace exporter URL is invalid")
        }
        let tracesUrl = url.appending(path: Configuration.otlpTracesEndpoint)
        let otlpHttpTraceExporter = OtlpHttpTraceExporter(
            endpoint: tracesUrl,
            envVarHeaders: configuration.customHeaders
        )
        let stdoutExporter = StdoutSpanExporter()
        let spanExporter = MultiSpanExporter(spanExporters: [otlpHttpTraceExporter, stdoutExporter])

        let spanProcessor = SimpleSpanProcessor(spanExporter: spanExporter)
        let traceProvider = TracerProviderBuilder()
            .add(spanProcessor: spanProcessor)
            .with(resource: resource)
            .build()
        OpenTelemetry.registerTracerProvider(tracerProvider: traceProvider)
        
        OpenTelemetry.registerPropagators(
            textPropagators: [
                W3CTraceContextPropagator(),
                B3Propagator(),
                JaegerPropagator(),
            ],
            baggagePropagator: W3CBaggagePropagator()
        )
    }
    
    // MARK: - Initialize Logs
    
    func initializeLogs() {
        guard let url = URL(string: configuration.otlpEndpoint) else {
            return print("Trace exporter URL is invalid")
        }
        let logsUrl = url.appending(path: Configuration.otlpLogsEndpoint)
        
        let httpLogExporter = OtlpHttpLogExporter(
            endpoint: logsUrl
        )
        
        OpenTelemetry.registerLoggerProvider(
            loggerProvider: LoggerProviderBuilder()
                .with(
                    processors: [
                        BatchLogRecordProcessor(
                            logRecordExporter: httpLogExporter
                        )
                    ]
                )
                .with(
                    resource: resource
                )
                .build()
        )
    }
    
    // MARK: - Initialize Metrics
    
    func initializeMetrics() {
        guard let url = URL(string: configuration.otlpEndpoint) else {
            return print("Trace exporter URL is invalid")
        }
        let metricsUrl = url.appending(path: Configuration.otlpMetricsEndpoint)
        
        
        let otlpMetricExporter = StableOtlpHTTPMetricExporter(
            endpoint: metricsUrl
        )
        let reader = StablePeriodicMetricReaderBuilder(exporter: otlpMetricExporter)
            .setInterval(timeInterval: 60.0)
            .build()
        let meterProvider = StableMeterProviderSdk.builder()
            .registerView(
                selector: InstrumentSelector.builder().setInstrument(name: ".*").build(),
                view: StableView.builder().build()
            )
            .registerMetricReader(reader: reader)
            .build()
        
        OpenTelemetry.registerStableMeterProvider(meterProvider: meterProvider)
    }
}


/*
let exporter: StableOtlpHTTPMetricExporter = StableOtlpHTTPMetricExporter(endpoint: defaultStableOtlpHTTPMetricsEndpoint())
let reader: StableMetricReader = StablePeriodicMetricReaderBuilder(exporter: exporter).setInterval(timeInterval: TimeInterval(60)).build()
var meterProvider: StableMeterProviderSdk = StableMeterProviderBuilder()
  .registerView(selector: InstrumentSelector.builder().setInstrument(name: ".*").build(), view: StableView.builder().build())
  .registerMetricReader(reader:reader)
  .build()

OpenTelemetry.registerStableMeterProvider(meterProvider: meterProvider)

let meter = OpenTelemetry.instance.stableMeterProvider?.meterBuilder(name: "SomeMeter").build()
var gaugeBuilder = meter!.gaugeBuilder(name: "demo_gauge").buildWithCallback({ ObservableDoubleMeasurement in
  ObservableDoubleMeasurement.record(value: 1.0, attributes: ["some_attribute": AttributeValue.bool(true)])
})

let flushResult = meterProvider.forceFlush()
print(flushResult)
sleep(2) // <- Without this sleep call, the network request does not get time to trigger and the metric is never submitted.
*/
