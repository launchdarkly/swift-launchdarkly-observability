import Foundation
@preconcurrency import OpenTelemetryApi
@preconcurrency import OpenTelemetrySdk
@preconcurrency import OpenTelemetryProtocolExporterHttp
@preconcurrency import StdoutExporter

import SignPostIntegration



public actor InstrumentationManager {
    private let openTelemetry: OpenTelemetry
    private let tracerProvider: TracerProvider
    
    private let serviceName: String
    private let serviceVersion: String
    
    private let sessionManager: SessionManager
    
    public init(
        serviceName: String = "launchdarkly-observability-swift",
        serviceVersion: String = "1.0.0",
        openTelemetry: OpenTelemetry = OpenTelemetry.instance,
        sessionManager: SessionManager = SessionManager()
    ) {
        let url = URL(string: "https://otel.observability.app.launchdarkly.com:4318/v1/traces")!
        let otlpHttpTraceExporter = OtlpHttpTraceExporter(
            endpoint: url,
            envVarHeaders: [
                ("X-LaunchDarkly-Project", "sdk-465cf811-71a3-42ee-8a9f-e325b6ed3a26")
            ]
        )
        
        
        let stdoutExporter = StdoutSpanExporter()
        let spanExporter = MultiSpanExporter(spanExporters: [otlpHttpTraceExporter, stdoutExporter])

        let spanProcessor = SimpleSpanProcessor(spanExporter: spanExporter)
        
        // TODO: api and sdk keys as env. variables
        let resource = Resource(
            attributes: [
                ResourceAttributes.serviceName.rawValue: AttributeValue.string(serviceName),
                ResourceAttributes.serviceVersion.rawValue: AttributeValue.string(serviceVersion),
                ResourceAttributes.telemetrySdkName.rawValue: AttributeValue.string("swift-launchdarkly-observability"),
                ResourceAttributes.telemetrySdkLanguage.rawValue: AttributeValue.string("swift"),
                "highlight.project_id": AttributeValue.string("sdk-465cf811-71a3-42ee-8a9f-e325b6ed3a26"),
                "highlight.session_id": AttributeValue.string(UUID().uuidString),
                "X-LaunchDarkly-Project": AttributeValue.string("6830e8e9e63ae80ddde9384b")
            ]
        )
        
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
        
        self.serviceName = serviceName
        self.serviceVersion = serviceVersion
        self.openTelemetry = openTelemetry
        self.tracerProvider = traceProvider
        self.sessionManager = sessionManager
        
        if #available(iOS 15.0, macOS 12, tvOS 15.0, watchOS 8.0, *) {
            let tracerProviderSDK = OpenTelemetry.instance.tracerProvider as? TracerProviderSdk
            tracerProviderSDK?.addSpanProcessor(OSSignposterIntegration())
        } else {
            let tracerProviderSDK = OpenTelemetry.instance.tracerProvider as? TracerProviderSdk
            tracerProviderSDK?.addSpanProcessor(SignPostIntegration())
        }
    }
    
    private func getTracer() -> Tracer {
        tracerProvider.get(instrumentationName: serviceName, instrumentationVersion: serviceVersion)
    }
    
    let sampleKey = "sampleKey"
    let sampleValue = "sampleValue"
}

// TODO: Remove test code
extension InstrumentationManager {
    public func createSpans() {
        let tracer = getTracer()
        let parentSpan1 = tracer.spanBuilder(spanName: "main").setSpanKind(spanKind: .client).startSpan()
        parentSpan1.setAttribute(key: sampleKey, value: sampleValue)
//        ("X-LaunchDarkly-Project", "sdk-465cf811-71a3-42ee-8a9f-e325b6ed3a26")
//        parentSpan1.setAttribute(key: "X-LaunchDarkly-Project", value: .string("sdk-465cf811-71a3-42ee-8a9f-e325b6ed3a26"))
        openTelemetry.contextProvider.setActiveSpan(parentSpan1)
        for _ in 1 ... 3 {
            doWork()
        }
        Thread.sleep(forTimeInterval: 0.5)
        
        let parentSpan2 = tracer.spanBuilder(spanName: "another").setSpanKind(spanKind: .client).setActive(true).startSpan()
        parentSpan2.setAttribute(key: sampleKey, value: sampleValue)
        // do more Work
        for _ in 1 ... 3 {
            doWork()
        }
        Thread.sleep(forTimeInterval: 0.5)
        
        parentSpan2.end()
        parentSpan1.end()
    }

    func doWork() {
        let tracer = getTracer()
        let childSpan = tracer.spanBuilder(spanName: "doWork").setSpanKind(spanKind: .client).startSpan()
        childSpan.setAttribute(key: sampleKey, value: sampleValue)
        Thread.sleep(forTimeInterval: Double.random(in: 0 ..< 10) / 100)
        childSpan.end()
    }
}
