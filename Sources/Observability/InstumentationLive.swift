import Foundation
import OSLog
import UIKit.UIWindow

import OpenTelemetrySdk
import OpenTelemetryApi
import OpenTelemetryProtocolExporterHttp
import URLSessionInstrumentation

import API
import Common
import CrashReporter
import CrashReporterLive
import Sampling
import SamplingLive
import Instrumentation

extension Instrumentation {
    private static let tracesPath = "/v1/traces"
    private static let logsPath = "/v1/logs"
    private static let metricsPath = "/v1/metrics"
    
    static func build(
        sdkKey: String,
        options: Options,
        sessionManager: SessionManager,
        flushTimeout: TimeInterval = 5.0
    ) -> Self {
        
        final class InstrumentationManager {
            private let sdkKey: String
            private let options: Options
            private let sessionManager: SessionManager
            private let flushTimeout: TimeInterval
            
            private var crashReporter: CrashReporter?
            private let lock: NSLock = NSLock()
            private let tapHandler = TapHandler()
            private let swipeHandler = SwipeHandler()
            
            private var cachedGauges = AtomicDictionary<String, DoubleGauge>()
            private var cachedCounters = AtomicDictionary<String, DoubleCounter>()
            private var cachedLongCounters = AtomicDictionary<String, LongCounter>()
            private var cachedHistograms = AtomicDictionary<String, DoubleHistogram>()
            private var cachedUpDownCounters = AtomicDictionary<String, DoubleUpDownCounter>()
            
            private var otelLogger: (any OpenTelemetryApi.Logger)
            private var otelTracer: Tracer?
            private var otelMeter: (any Meter)
            
            private var urlSessionInstrumentation: URLSessionInstrumentation?
            private var flushSpanProcessor: (_ timeout: TimeInterval?) -> Void = { _ in }
            private var flushBatchLogRecordProcessor: (_ explicitTimeout: TimeInterval?) -> ExportResult = { _ in .success }
            private var flushMeterReader: () -> ExportResult = { .success }
            
            init(sdkKey: String, options: Options, sessionManager: SessionManager, flushTimeout: TimeInterval = 5.0) {
                self.sdkKey = sdkKey
                self.options = options
                self.sessionManager = sessionManager
                self.flushTimeout = flushTimeout
                
                /// Load default instrumentation (logger, tracer, meter are no-op)
                self.otelLogger = OpenTelemetry.instance.loggerProvider.get(
                    instrumentationScopeName: options.serviceName
                )
                
                self.otelTracer = OpenTelemetry.instance.tracerProvider.get(
                    instrumentationName: options.serviceName,
                    instrumentationVersion: options.serviceVersion
                )
                
                self.otelMeter = OpenTelemetry.instance.meterProvider.get(
                    name: options.serviceName
                )

                Task { [weak self] in
                    do {
                        let graphQLClient = URL(string: options.backendUrl).map { GraphQLClient(endpoint: $0) }
                        let samplingConfigClient = DefaultSamplingConfigClient(client: graphQLClient)
                        let config = try await samplingConfigClient.getSamplingConfig(sdkKey: sdkKey)
                        self?.initializeInstrumentation(withConfig: config, options: options)
                        self?.install()
                    } catch {
                        os_log("%{public}@", log: LDLogger, type: .error, "getSamplingConfig failed with error: \(error)")
                        self?.initializeInstrumentation(withConfig: nil, options: options)
                        self?.install()
                    }
                }
            }
            
            // MARK: - Install Crash Reporter
            private func installCrashReporter(_ crashReporter: CrashReporter) {
                do {
                    try crashReporter.install()
                    crashReporter.logPendingCrashReports()
                    self.crashReporter = crashReporter
                } catch {
                    os_log("%{public}@", log: LDLogger, type: .error, "Crash Reporter installation failed with error: \(error)")
                }
            }
            
            // MARK: - Init Instrumentation
            private func initializeTracer(withSampler sampler: ExportSampler) {
                if let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(Instrumentation.tracesPath) {
                    let exporter = SamplingTraceExporterDecorator(
                        exporter: OtlpHttpTraceExporter(
                            endpoint: url,
                            envVarHeaders: options.customHeaders
                        ),
                        sampler: sampler
                    )
                    /// Using the default values from OpenTelemetry for Swift
                    /// For reference check:
                    ///https://github.com/open-telemetry/opentelemetry-swift/blob/main/Sources/OpenTelemetrySdk/Trace/SpanProcessors/BatchSpanProcessor.swift
                    let processor = BatchSpanProcessor(
                        spanExporter: exporter,
                        scheduleDelay: 5,
                        exportTimeout: 30,
                        maxQueueSize: 2048,
                        maxExportBatchSize: 512,
                    )
                    
                    self.flushSpanProcessor = {
                        processor.forceFlush(timeout: $0)
                    }
                    
                    let provider = TracerProviderBuilder()
                        .add(spanProcessor: processor)
                        .with(resource: Resource(attributes: options.resourceAttributes))
                        .build()
                    
                    /// Register Custom Tracer Provider
                    OpenTelemetry.registerTracerProvider(
                        tracerProvider: provider
                    )
                    
                    /// Update tracer instance
                    self.otelTracer = OpenTelemetry.instance.tracerProvider.get(
                        instrumentationName: options.serviceName,
                        instrumentationVersion: options.serviceVersion
                    )
                }
            }
            
            private func initializeLogger(withSampler sampler: ExportSampler) {
                if let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(Instrumentation.logsPath) {
                    let exporter = MultiLogRecordExporter(
                        logRecordExporters: options.isDebug ? [
                            SamplingLogExporterDecorator(
                                exporter: OtlpHttpLogExporter(
                                    endpoint: url,
                                    envVarHeaders: options.customHeaders
                                ),
                                sampler: sampler
                            ),
                            LDStdoutExporter(loggerName: options.loggerName)
                        ] : [
                            SamplingLogExporterDecorator(
                                exporter: OtlpHttpLogExporter(
                                    endpoint: url,
                                    envVarHeaders: options.customHeaders
                                ),
                                sampler: sampler
                            )
                        ]
                    )
                    
                    /// Using the default values from OpenTelemetry for Swift
                    /// For reference check:
                    ///https://github.com/open-telemetry/opentelemetry-swift/blob/main/Sources/OpenTelemetrySdk/Logs/Processors/BatchLogRecordProcessor.swift
                    let processor = BatchLogRecordProcessor(
                        logRecordExporter: exporter,
                        scheduleDelay: 5,
                        exportTimeout: 30,
                        maxQueueSize: 2048,
                        maxExportBatchSize: 512
                    )
                    
                    self.flushBatchLogRecordProcessor = {
                        processor.forceFlush(explicitTimeout: $0)
                    }
                    
                    let provider = LoggerProviderBuilder()
                        .with(
                            processors: [
                                processor
                            ]
                        )
                        .with(resource: Resource(attributes: options.resourceAttributes))
                        .build()
                    
                    /// Register custom logger
                    OpenTelemetry.registerLoggerProvider(
                        loggerProvider: provider
                    )
                    
                    /// Update logger instance
                    self.otelLogger = OpenTelemetry.instance.loggerProvider.get(
                        instrumentationScopeName: options.serviceName
                    )
                    
                    let crashReporter = CrashReporter.otelReporter(
                        logger: otelLogger,
                        otelBatchLogRecordProcessor: processor
                    ) {}
                    self.installCrashReporter(crashReporter)
                }
            }
            
            private func initializeMeter() {
                if let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(Instrumentation.metricsPath) {
                    let exporter = OtlpHttpMetricExporter(
                        endpoint: url,
                        envVarHeaders: options.customHeaders
                    )
                    
                    let reader = PeriodicMetricReaderBuilder(exporter: exporter)
                        .setInterval(timeInterval: 10.0)
                        .build()
                    
                    self.flushMeterReader = {
                        reader.forceFlush()
                    }
                    
                    let provider = MeterProviderSdk.builder()
                        .registerView(
                            selector: InstrumentSelector.builder().setInstrument(name: options.serviceName).build(),
                            view: View.builder().build()
                        )
                        .registerMetricReader(
                            reader: reader
                        )
                        .build()
                    
                    /// Register custom meter
                    OpenTelemetry.registerMeterProvider(
                        meterProvider: provider
                    )
                    
                    /// Update meter instance
                    self.otelMeter = OpenTelemetry.instance.meterProvider.get(
                        name: options.serviceName
                    )
                }
            }
            
            private func initializeInstrumentation(withConfig samplerConfig: SamplingConfig?, options: Options) {
                let sampler = ExportSampler.customSampler()
                sampler.setConfig(samplerConfig)
                initializeTracer(withSampler: sampler)
                initializeLogger(withSampler: sampler)
                initializeMeter()
                self.urlSessionInstrumentation = URLSessionInstrumentation(
                    configuration: URLSessionInstrumentationConfiguration(
                        shouldInstrument: { urlRequest in
                            urlRequest.url?.absoluteString.contains(options.otlpEndpoint) == false &&
                            urlRequest.url?.absoluteString.contains("https://mobile.launchdarkly.com/mobile") == false
                        },
                        nameSpan: { request in
                            "http.request"
                        },
                        spanCustomization: { request, spanBuilder in
                            if let httpMethod = request.httpMethod {
                                spanBuilder.setAttribute(key: "http.method", value: httpMethod)
                            }
                            if let url = request.url {
                                spanBuilder.setAttribute(key: "http.url", value: url.absoluteString)
                            }
                        },
                        tracer: self.otelTracer
                    )
                )
            }
            
            // MARK: - Interaction
            
            private func install() {
                lock.lock()
                defer { lock.unlock() }
                UIWindowSendEvent.inject { [weak self] uiWindow, uiEvent in
                    guard let self = self else { return }
                    
                    self.tapHandler.handle(event: uiEvent, window: uiWindow) { [weak self] touchEvent in
                        guard let self = self else { return }
                        
                        var attributes = [String: AttributeValue]()
                        attributes["screen.name"] = .string(touchEvent.viewName)
                        attributes["target.id"] = .string(touchEvent.accessibilityIdentifier ?? touchEvent.viewName)
                        // sending location in points (since it is preferred over pixels)
                        attributes["position.x"] = .string(touchEvent.locationInPoints.x.toString())
                        attributes["position.y"] = .string(touchEvent.locationInPoints.y.toString())
                        self.startSpan(name: "user.tap", attributes: attributes).end()
                    }
                    self.swipeHandler.handle(event: uiEvent, window: uiWindow) { [weak self] touchEvent in
                        guard let self = self else { return }
                        
                        var attributes = [String: AttributeValue]()
                        attributes["screen.name"] = .string(touchEvent.viewName)
                        attributes["target.id"] = .string(touchEvent.accessibilityIdentifier ?? touchEvent.viewName)
                        // sending location in points (since it is preferred over pixels)
                        attributes["position.x"] = .string(touchEvent.locationInPoints.x.toString())
                        attributes["position.y"] = .string(touchEvent.locationInPoints.y.toString())
                        self.startSpan(name: "user.swipe", attributes: attributes).end()
                    }
                }
            }
            
            // MARK: - Instrumentation
            
            func recordMetric(metric: Metric) {
                var gauge = cachedGauges[metric.name]
                if gauge == nil {
                    gauge = otelMeter
                        .gaugeBuilder(name: metric.name)
                        .build()
                    cachedGauges[metric.name] = gauge
                }
                gauge?.record(value: metric.value, attributes: metric.attributes)
            }
            
            func recordCount(metric: Metric) {
                var counter = cachedCounters[metric.name]
                if counter == nil {
                    counter = otelMeter.counterBuilder(name: metric.name).ofDoubles().build()
                    cachedCounters[metric.name] = counter
                }
                counter?.add(value: metric.value, attributes: metric.attributes)
            }
            
            func recordIncr(metric: Metric) {
                var counter = cachedLongCounters[metric.name]
                if counter == nil {
                    counter = otelMeter.counterBuilder(name: metric.name).build()
                    cachedLongCounters[metric.name] = counter
                }
                counter?.add(value: 1, attributes: metric.attributes)
            }
            
            func recordHistogram(metric: Metric) {
                var histogram = cachedHistograms[metric.name]
                if histogram == nil {
                    histogram = otelMeter.histogramBuilder(name: metric.name).build()
                    cachedHistograms[metric.name] = histogram
                }
                histogram?.record(value: metric.value, attributes: metric.attributes)
            }
            
            func recordUpDownCounter(metric: Metric) {
                var upDownCounter = cachedUpDownCounters[metric.name]
                if upDownCounter == nil {
                    upDownCounter = otelMeter.upDownCounterBuilder(name: metric.name).ofDoubles().build()
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
                otelLogger.logRecordBuilder()
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
            
            func flush() -> Bool {
                /// There is no export result span processor in the SpanProcessor protocol
                flushSpanProcessor(flushTimeout)
                
                let flushedLogsSucceeded = flushBatchLogRecordProcessor(flushTimeout).isSuccess
                let flushedMetricsSucceeded = flushMeterReader().isSuccess
                
                return flushedLogsSucceeded && flushedMetricsSucceeded
            }
        }
        
        let manager = InstrumentationManager(
            sdkKey: sdkKey,
            options: options,
            sessionManager: sessionManager
        )
        
        return Self(
            recordMetric: { manager.recordMetric(metric: $0) },
            recordCount: { manager.recordCount(metric: $0) },
            recordIncr: { manager.recordIncr(metric: $0) },
            recordHistogram: { manager.recordHistogram(metric: $0) },
            recordUpDownCounter: { manager.recordUpDownCounter(metric: $0) },
            recordError: { manager.recordError(error: $0, attributes: $1) },
            recordLog: { manager.recordLog(message: $0, severity: $1, attributes: $2) },
            startSpan: { manager.startSpan(name: $0, attributes: $1) },
            flush: { manager.flush() }
        )
    }
}

extension ExportResult {
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}
