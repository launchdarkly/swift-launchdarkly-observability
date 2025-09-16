import Foundation

import OpenTelemetrySdk
import OpenTelemetryApi
import OpenTelemetryProtocolExporterHttp
import URLSessionInstrumentation

import Common
import API
import Sampling
import SamplingLive

private let tracesPath = "/v1/traces"
private let logsPath = "/v1/logs"
private let metricsPath = "/v1/metrics"

final class InstrumentationManager {
    private let sdkKey: String
    private let options: Options
    let otelLogger: Logger?
    let otelTracer: Tracer?
    let otelMeter: (any Meter)?
    public let otelBatchLogRecordProcessor: BatchLogRecordProcessor?
    private let sessionManager: SessionManager
    private let urlSessionInstrumentation: URLSessionInstrumentation
    private var cachedGauges = AtomicDictionary<String, DoubleGauge>()
    private var cachedCounters = AtomicDictionary<String, DoubleCounter>()
    private var cachedLongCounters = AtomicDictionary<String, LongCounter>()
    private var cachedHistograms = AtomicDictionary<String, DoubleHistogram>()
    private var cachedUpDownCounters = AtomicDictionary<String, DoubleUpDownCounter>()
    private let sampler: ExportSampler
    
    public init(sdkKey: String, options: Options, sessionManager: SessionManager) {
        self.sdkKey = sdkKey
        self.options = options
        self.sessionManager = sessionManager
        
        
        let sampler = ExportSampler.customSampler()
        /// Here is how we will inject the sampling config coming from backend, if the next lines
        /// are uncommented, them will inject a example local config for testing purposes only.
        ///let samplingConfig = loadSampleConfig()
        ///sampler.setConfig(samplingConfig)
        
        
        let processorAndProvider = URL(string: options.otlpEndpoint)
            .flatMap {
                if #available(iOS 16, *) {
                    return $0.appending(path: logsPath)
                }
                else {
                    return $0.appendingPathComponent(logsPath)
                }
            }
            .map { url in
                SamplingLogExporterDecorator(
                    exporter: OtlpHttpLogExporter(
                        endpoint: url,
                        envVarHeaders: options.customHeaders
                    ),
                    sampler: sampler
                )
            }
            .map { exporter in
                /// Using the default values from OpenTelemetry for Swift
                /// For reference check:
                /// https://github.com/open-telemetry/opentelemetry-swift/blob/main/Sources/OpenTelemetrySdk/Logs/Processors/BatchLogRecordProcessor.swift
                let processor = BatchLogRecordProcessor(
                    logRecordExporter: exporter,
                    scheduleDelay: 5,
                    exportTimeout: 30,
                    maxQueueSize: 2048,
                    maxExportBatchSize: 512
                )
                let provider = LoggerProviderBuilder().with(
                    processors: [
                        processor
                    ]
                )
                    .with(resource: Resource(attributes: options.resourceAttributes))
                    .build()
                return (processor, provider)
            }
            .map { (arg0)  in
                let (processor, loggerProvider) = arg0
                OpenTelemetry.registerLoggerProvider(
                    loggerProvider: loggerProvider
                )
                return (processor, loggerProvider)
            }
        
        URL(string: options.otlpEndpoint)
            .flatMap {
                if #available(iOS 16, *) {
                    return $0.appending(path: tracesPath)
                }
                else {
                    return $0.appendingPathComponent(tracesPath)
                }
            }
            .map { url in
                SamplingTraceExporterDecorator(
                    exporter: OtlpHttpTraceExporter(
                        endpoint: url,
                        envVarHeaders: options.customHeaders
                    ),
                    sampler: sampler
                )
            }
            .map { exporter in
                /// Using the default values from OpenTelemetry for Swift
                /// For reference check:
                /// https://github.com/open-telemetry/opentelemetry-swift/blob/main/Sources/OpenTelemetrySdk/Trace/SpanProcessors/BatchSpanProcessor.swift
                BatchSpanProcessor(
                    spanExporter: exporter,
                    scheduleDelay: 5,
                    exportTimeout: 30,
                    maxQueueSize: 2048,
                    maxExportBatchSize: 512,
                )
            }
            .map { processor in
                TracerProviderBuilder()
                    .add(spanProcessor: processor)
                    .with(resource: Resource(attributes: options.resourceAttributes))
                    .build()
            }
            .map { tracerProvider in
                OpenTelemetry.registerTracerProvider(
                    tracerProvider: tracerProvider
                )
            }
        
        URL(string: options.otlpEndpoint)
            .flatMap {
                if #available(iOS 16, *) {
                    return $0.appending(path: metricsPath)
                }
                else {
                    return $0.appendingPathComponent(metricsPath)
                }
            }
            .map { url in
                OtlpHttpMetricExporter(
                    endpoint: url,
                    envVarHeaders: options.customHeaders
                )
            }
            .map { exporter in
                PeriodicMetricReaderBuilder(exporter: exporter)
                    .setInterval(timeInterval: 10.0)
                    .build()
            }
            .map { reader in
                MeterProviderSdk.builder()
                    .registerView(
                        selector: InstrumentSelector.builder().setInstrument(name: options.serviceName).build(),
                        view: View.builder().build()
                    )
                    .registerMetricReader(
                        reader: reader
                    )
                    .build()
            }
            .map { meterProvider in
                OpenTelemetry.registerMeterProvider(
                    meterProvider: meterProvider
                )
            }
        
        self.otelBatchLogRecordProcessor = processorAndProvider?.0
        self.otelLogger =  OpenTelemetry.instance.loggerProvider.get(
            instrumentationScopeName: options.serviceName
        )
        
        self.otelTracer = OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: options.serviceName,
            instrumentationVersion: options.serviceVersion
        )
        
        self.otelMeter = OpenTelemetry.instance.meterProvider.get(
            name: options.serviceName
        )
        
        self.urlSessionInstrumentation = URLSessionInstrumentation(
            configuration: URLSessionInstrumentationConfiguration(
                shouldInstrument: { urlRequest in
                    urlRequest.url?.absoluteString.contains(options.otlpEndpoint) == false &&
                    urlRequest.url?.absoluteString.contains("https://mobile.launchdarkly.com/mobile") == false
                },
                tracer: self.otelTracer
            )
        )
        
        self.sampler = sampler
    }
    
    func recordMetric(metric: Metric) {
        var gauge = cachedGauges[metric.name]
        if gauge == nil {
            gauge = otelMeter?
                .gaugeBuilder(name: metric.name)
                .build()
            cachedGauges[metric.name] = gauge
        }
        gauge?.record(value: metric.value, attributes: metric.attributes)
    }
    
    func recordCount(metric: Metric) {
        var counter = cachedCounters[metric.name]
        if counter == nil {
            counter = otelMeter?.counterBuilder(name: metric.name).ofDoubles().build()
            cachedCounters[metric.name] = counter
        }
        counter?.add(value: metric.value, attributes: metric.attributes)
    }
    
    func recordIncr(metric: Metric) {
        var counter = cachedLongCounters[metric.name]
        if counter == nil {
            counter = otelMeter?.counterBuilder(name: metric.name).build()
            cachedLongCounters[metric.name] = counter
        }
        counter?.add(value: 1, attributes: metric.attributes)
    }
    
    func recordHistogram(metric: Metric) {
        var histogram = cachedHistograms[metric.name]
        if histogram == nil {
            histogram = otelMeter?.histogramBuilder(name: metric.name).build()
            cachedHistograms[metric.name] = histogram
        }
        histogram?.record(value: metric.value, attributes: metric.attributes)
    }
    
    func recordUpDownCounter(metric: Metric) {
        var upDownCounter = cachedUpDownCounters[metric.name]
        if upDownCounter == nil {
            upDownCounter = otelMeter?.upDownCounterBuilder(name: metric.name).ofDoubles().build()
            cachedUpDownCounters[metric.name] = upDownCounter
        }
        upDownCounter?.add(value: metric.value, attributes: metric.attributes)
    }
    
    func recordLog(message: String, severity: Severity, attributes: [String: AttributeValue]) {
        var attributes = attributes
        let sessionId = sessionManager.sessionInfo.id
        if !sessionId.isEmpty {
            attributes[SemanticConvention.highlightSessionId] = .string(sessionId)
        }
        otelLogger?.logRecordBuilder()
            .setBody(.string(message))
            .setTimestamp(Date())
            .setSeverity(severity)
            .setAttributes(attributes)
            .emit()
    }
    
    func recordError(error: Error, attributes: [String: AttributeValue]) {
        var attributes = attributes
        let builder = otelTracer?.spanBuilder(spanName: "highlight.error")
        
        if let parent = OpenTelemetry.instance.contextProvider.activeSpan {
            builder?.setParent(parent)
        }
        
        attributes.forEach {
            builder?.setAttribute(key: $0.key, value: $0.value)
        }
        
        let sessionId = sessionManager.sessionInfo.id
        if !sessionId.isEmpty {
            builder?.setAttribute(key: SemanticConvention.highlightSessionId, value: sessionId)
            attributes[SemanticConvention.highlightSessionId] = .string(sessionId)
        }
        
        
        let span = builder?.startSpan()
        span?.setAttributes(attributes)
        span?.recordException(ErrorSpanException(error: error), attributes: attributes)
        span?.end()
    }
    
    func startSpan(name: String, attributes: [String: AttributeValue]) -> any Span {
        let tracer: Tracer
        if let otelTracer {
            tracer = otelTracer
        } else {
            tracer = OpenTelemetry.instance.tracerProvider.get(
                instrumentationName: options.serviceName,
                instrumentationVersion: options.serviceVersion
            )
        }
        
        let builder = tracer.spanBuilder(spanName: name)
        
        if let parent = OpenTelemetry.instance.contextProvider.activeSpan {
            builder.setParent(parent)
        }
        
        attributes.forEach {
            builder.setAttribute(key: $0.key, value: $0.value)
        }
        
        return builder.startSpan()
    }
}

func loadSampleConfig() -> SamplingConfig? {
    guard let url = Bundle.module.url(forResource: "Config", withExtension: "json") else {
        return nil
    }
    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let root = try decoder.decode(Root.self, from: data)
        return root.data.sampling
    } catch {
        return nil
    }
}
