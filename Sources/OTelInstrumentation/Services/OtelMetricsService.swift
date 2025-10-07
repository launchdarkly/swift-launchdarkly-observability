import Foundation

import OpenTelemetrySdk
import OpenTelemetryApi

import Common
import ApplicationServices

final class OTelMetricsService {
    private let sessionService: SessionService
    private let options: Options
    private let exporter: MetricExporter
    
    private let meter: (any Meter)
    private let periodicMetricReader: PeriodicMetricReaderSdk
    
    private var cachedGauges = AtomicDictionary<String, DoubleGauge>()
    private var cachedCounters = AtomicDictionary<String, DoubleCounter>()
    private var cachedLongCounters = AtomicDictionary<String, LongCounter>()
    private var cachedHistograms = AtomicDictionary<String, DoubleHistogram>()
    private var cachedUpDownCounters = AtomicDictionary<String, DoubleUpDownCounter>()
    
    init(
        sessionService: SessionService,
        options: Options,
        exporter: MetricExporter
    ) {
        
        let reader = PeriodicMetricReaderBuilder(exporter: exporter)
            .setInterval(timeInterval: 5.0)
            .build()
        
        let provider = MeterProviderSdk.builder()
            .registerView(
                selector: InstrumentSelector.builder().setInstrument(name: ".*").build(),
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
        self.meter = OpenTelemetry.instance.meterProvider.get(
            name: options.serviceName
        )
        self.periodicMetricReader = reader
        self.sessionService = sessionService
        self.options = options
        self.exporter = exporter
    }
    
    // MARK: - API
    
    func recordMetric(metric: Metric) {
        var gauge = cachedGauges[metric.name]
        if gauge == nil {
            gauge = meter
                .gaugeBuilder(name: metric.name)
                .build()
            cachedGauges[metric.name] = gauge
        }
        gauge?.record(value: metric.value, attributes: metric.attributes.mapValues { $0.toOTel() })
    }
    
    func recordCount(metric: Metric) {
        var counter = cachedCounters[metric.name]
        if counter == nil {
            counter = meter.counterBuilder(name: metric.name).ofDoubles().build()
            cachedCounters[metric.name] = counter
        }
        counter?.add(value: metric.value, attributes: metric.attributes.mapValues { $0.toOTel() })
    }
    
    func recordIncr(metric: Metric) {
        var counter = cachedLongCounters[metric.name]
        if counter == nil {
            counter = meter.counterBuilder(name: metric.name).build()
            cachedLongCounters[metric.name] = counter
        }
        counter?.add(value: 1, attributes: metric.attributes.mapValues { $0.toOTel() })
    }
    
    func recordHistogram(metric: Metric) {
        var histogram = cachedHistograms[metric.name]
        if histogram == nil {
            histogram = meter.histogramBuilder(name: metric.name).build()
            cachedHistograms[metric.name] = histogram
        }
        histogram?.record(value: metric.value, attributes: metric.attributes.mapValues { $0.toOTel() })
    }
    
    func recordUpDownCounter(metric: Metric) {
        var upDownCounter = cachedUpDownCounters[metric.name]
        if upDownCounter == nil {
            upDownCounter = meter.upDownCounterBuilder(name: metric.name).ofDoubles().build()
            cachedUpDownCounters[metric.name] = upDownCounter
        }
        upDownCounter?.add(value: metric.value, attributes: metric.attributes.mapValues { $0.toOTel() })
    }
    
    func flush() async -> Bool {
        await withCheckedContinuation { continuation in
            continuation.resume(
                returning: periodicMetricReader.forceFlush() == .success
            )
        }
    }
}
