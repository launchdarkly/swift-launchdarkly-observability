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
import SessionReplay

final class InstrumentationManager {
    private let context: ObservabilityContext
    private let sessionManager: SessionManager
    private let flushTimeout: TimeInterval
    private let graphQLClient: GraphQLClient
    private var sessionReplayService: SessionReplayService?
    
    private var crashReporter: CrashReporter?
    private let lock: NSLock = NSLock()
    private let tapHandler = TapHandler()
    private let swipeHandler = SwipeHandler()
    
    private var cachedGauges = AtomicDictionary<String, DoubleGauge>()
    private var cachedCounters = AtomicDictionary<String, DoubleCounter>()
    private var cachedLongCounters = AtomicDictionary<String, LongCounter>()
    private var cachedHistograms = AtomicDictionary<String, DoubleHistogram>()
    private var cachedUpDownCounters = AtomicDictionary<String, DoubleUpDownCounter>()
    
    private let sampler = ExportSampler.customSampler()
    private var otelLogger: (any OpenTelemetryApi.Logger)
    private var otelTracer: Tracer?
    private var otelMeter: (any Meter)
    
    private var urlSessionInstrumentation: URLSessionInstrumentation?
    private var flushSpanProcessor: (_ timeout: TimeInterval?) -> Void = { _ in }
    private var flushBatchLogRecordProcessor: (_ explicitTimeout: TimeInterval?) -> ExportResult = { _ in .success }
    private var flushMeterReader: () -> ExportResult = { .success }
    
    init(
        context: ObservabilityContext,
        sessionManager: SessionManager,
        flushTimeout: TimeInterval = 5.0
    ) throws {
        self.context = context
        self.sessionManager = sessionManager
        self.flushTimeout = flushTimeout
        
        guard let url = URL(string: context.options.backendUrl) else {
            throw InstrumentationError.graphQLUrlIsInvalid
        }
        self.graphQLClient = GraphQLClient(endpoint: url)
    
        
        /// If options.otlpEndpoint is not a valid url use no-op instrumentation
        ///
        /// Load default instrumentation (logger, tracer, meter are no-op)
        self.otelLogger = OpenTelemetry.instance.loggerProvider.get(
            instrumentationScopeName: context.options.serviceName
        )
        
        self.otelTracer = OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: context.options.serviceName,
            instrumentationVersion: context.options.serviceVersion
        )
        
        self.otelMeter = OpenTelemetry.instance.meterProvider.get(
            name: context.options.serviceName
        )
        
        self.initializeInstrumentation(options: context.options)
        

        
        Task { [weak self] in
            guard let self else { return }
            do {
                let samplingConfigClient = DefaultSamplingConfigClient(client: graphQLClient)
                let config = try await samplingConfigClient.getSamplingConfig(sdkKey: context.sdkKey)
                self.sampler.setConfig(config)
            } catch {
                os_log("%{public}@", log: context.logger.log, type: .error, "getSamplingConfig failed with error: \(error)")
            }
        }
        
        self.install()
        self.sessionReplayService?.start()
    }
    
    // MARK: - Install Crash Reporter
    private func installCrashReporter(_ crashReporter: CrashReporter) {
        do {
            try crashReporter.install()
            crashReporter.logPendingCrashReports()
            self.crashReporter = crashReporter
        } catch {
            os_log("%{public}@", log: context.logger.log, type: .error, "Crash Reporter installation failed with error: \(error)")
        }
    }
    
    // MARK: - Init Instrumentation
    private func initializeTracer(withSampler sampler: ExportSampler, options: Options) {
        guard !options.disableTraces else {
            return /// currently tracer instance is a no-op, means, we don't want a custom tracer, we will use no-op
        }
        if let url = URL(string: context.options.otlpEndpoint)?.appendingPathComponent(Instrumentation.tracesPath) {
            let exporter = SamplingTraceExporterDecorator(
                exporter: OtlpHttpTraceExporter(
                    endpoint: url,
                    envVarHeaders: context.options.customHeaders
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
                .with(resource: Resource(attributes: context.options.resourceAttributes))
                .build()
            
            /// Register Custom Tracer Provider
            OpenTelemetry.registerTracerProvider(
                tracerProvider: provider
            )
            
            /// Update tracer instance
            self.otelTracer = OpenTelemetry.instance.tracerProvider.get(
                instrumentationName: context.options.serviceName,
                instrumentationVersion: context.options.serviceVersion
            )
        }
    }
    
    private func initializeLogger(withSampler sampler: ExportSampler, options: Options) {
        guard !options.disableLogs else {
            return /// currently logger instance is a no-op, means, we don't want a custom logger, we will use no-op
        }
        if let url = URL(string: context.options.otlpEndpoint)?.appendingPathComponent(Instrumentation.logsPath) {
            let samplingExporter = SamplingLogExporterDecorator(
                exporter: OtlpHttpLogExporter(
                    endpoint: url,
                    envVarHeaders: context.options.customHeaders
                ),
                sampler: sampler
            ),
                
            let exporter = MultiLogRecordExporter(
                logRecordExporters: context.options.isDebug ?
                [samplingExporter, LDStdoutExporter(logger: context.logger.log)] : [samplingExporter]
            )
            
            let observabilityExporter = ObservabilityExporter(logRecordExporter: exporter, networkClient: URLSessionNetworkClient())
            self.sessionReplayService = SessionReplayService(
                context: .init(
                    sdkKey: context.sdkKey,
                    serviceName: context.options.serviceName,
                    backendUrl: url,
                    graphQLClient: graphQLClient),
                sessionId: sessionManager.sessionInfo.id, observabilityExporter: observabilityExporter)
            
            
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
                .with(resource: Resource(attributes: context.options.resourceAttributes))
                .build()
            
            /// Register custom logger
            OpenTelemetry.registerLoggerProvider(
                loggerProvider: provider
            )
            
            /// Update logger instance
            self.otelLogger = OpenTelemetry.instance.loggerProvider.get(
                instrumentationScopeName: context.options.serviceName
            )
            
            let crashReporter = CrashReporter.otelReporter(
                logger: otelLogger,
                otelBatchLogRecordProcessor: processor
            ) {}
            self.installCrashReporter(crashReporter)
        }
    }
    
    private func initializeMeter(options: Options) {
        guard !options.disableMetrics else {
            return /// currently meter instance is a no-op, means, we don't want a custom meter, we will use no-op
        }
        if let url = URL(string: context.options.otlpEndpoint)?.appendingPathComponent(Instrumentation.metricsPath) {
            let exporter = OtlpHttpMetricExporter(
                endpoint: url,
                envVarHeaders: context.options.customHeaders
            )
            
            let reader = PeriodicMetricReaderBuilder(exporter: exporter)
                .setInterval(timeInterval: 10.0)
                .build()
            
            self.flushMeterReader = {
                reader.forceFlush()
            }
            
            let provider = MeterProviderSdk.builder()
                .registerView(
                    selector: InstrumentSelector.builder().setInstrument(name: context.options.serviceName).build(),
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
                name: context.options.serviceName
            )
        }
    }
    
    private func initializeInstrumentation(options: Options) {
        initializeTracer(withSampler: sampler, options: options)
        initializeLogger(withSampler: sampler, options: options)
        initializeMeter(options: options)
        self.urlSessionInstrumentation = URLSessionInstrumentation(
            configuration: URLSessionInstrumentationConfiguration(
                shouldInstrument: { urlRequest in
                    urlRequest.url?.absoluteString.contains(options.otlpEndpoint) == false &&
                    urlRequest.url?.absoluteString.contains("https://mobile.launchdarkly.com/mobile") == false &&
                    urlRequest.url?.absoluteString.contains(options.backendUrl) == false
                },
                nameSpan: { request in
                    "http.request"
                },
                spanCustomization: { [weak self] request, spanBuilder in
                    guard let self else { return }
                    
                    if let httpMethod = request.httpMethod {
                        spanBuilder.setAttribute(key: "http.method", value: httpMethod)
                    }
                    if let url = request.url {
                        spanBuilder.setAttribute(key: "http.url", value: url.absoluteString)
                    }
                    let sessionId = self.sessionManager.sessionInfo.id
                    if !sessionId.isEmpty {
                        spanBuilder.setAttribute(key: SemanticConvention.highlightSessionId, value: sessionId)
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
                
                sessionReplayService?.userTap(touchEvent: touchEvent)
                var attributes = [String: AttributeValue]()
                let viewName = touchEvent.viewName ?? "unknown"
                attributes["screen.name"] = .string(viewName)
                attributes["target.id"] = .string(touchEvent.accessibilityIdentifier ?? viewName)
                // sending location in points (since it is preferred over pixels)
                attributes["position.x"] = .string(touchEvent.locationInPoints.x.toString())
                attributes["position.y"] = .string(touchEvent.locationInPoints.y.toString())
                self.startSpan(name: "user.tap", attributes: attributes).end()
            }
            self.swipeHandler.handle(event: uiEvent, window: uiWindow) { [weak self] touchEvent in
                guard let self = self else { return }
                let viewName = touchEvent.viewName ?? "unknown"
                var attributes = [String: AttributeValue]()
                attributes["screen.name"] = .string(viewName)
                attributes["target.id"] = .string(touchEvent.accessibilityIdentifier ?? viewName)
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
        
        let logBuilder = ObservabilityLogRecordBuilder(queue: sessionReplayService!.eventQueue,
                                                          resource: context.resource,
                                                          clock: MillisClock(),
                                                          instrumentationScope: .init(name: context.options.serviceName),
                                                          includeSpanContext: true)
       
        //logBuilder
        otelLogger.logRecordBuilder().setBody(.string(message))
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
                instrumentationName: context.options.serviceName,
                instrumentationVersion: context.options.serviceVersion
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
