import OpenTelemetrySdk
import Common

final class MeterDecorator: Meter {
    private let meterProvider: any MeterProvider
    private let meter: MeterSdk
    private let meterReader: any MetricReader
    
    private var cachedGauges = AtomicDictionary<String, DoubleGauge>()
    private var cachedCounters = AtomicDictionary<String, DoubleCounter>()
    private var cachedLongCounters = AtomicDictionary<String, LongCounter>()
    private var cachedHistograms = AtomicDictionary<String, DoubleHistogram>()
    private var cachedUpDownCounters = AtomicDictionary<String, DoubleUpDownCounter>()
    
    init(options: Options, exporter: MetricExporter) {
        let reader = PeriodicMetricReaderBuilder(exporter: exporter)
            .setInterval(timeInterval: 10.0)
            .build()
        self.meterReader = reader
        
        let provider = MeterProviderSdk.builder()
            .registerView(
                selector: InstrumentSelector.builder().setInstrument(name: ".*").build(),
                view: View.builder().build()
            )
            .registerMetricReader(
                reader: reader
            )
            .build()
        self.meterProvider = provider
        self.meter = provider.get(name: options.serviceName)
    }
    
    func counterBuilder(name: String) -> LongCounterMeterBuilderSdk {
        meter.counterBuilder(name: name)
    }
    
    func upDownCounterBuilder(name: String) -> LongUpDownCounterBuilderSdk {
        meter.upDownCounterBuilder(name: name)
    }

    func histogramBuilder(name: String) -> DoubleHistogramMeterBuilderSdk {
        meter.histogramBuilder(name: name)
    }
    
    func gaugeBuilder(name: String) -> DoubleGaugeBuilderSdk {
        meter.gaugeBuilder(name: name)
    }
}

extension MeterDecorator: MetricsApi {
    public func recordMetric(metric: Metric) {
        var gauge = cachedGauges[metric.name]
        if gauge == nil {
            gauge = meter
                .gaugeBuilder(name: metric.name)
                .build()
            cachedGauges[metric.name] = gauge
        }
        gauge?.record(value: metric.value, attributes: metric.attributes)
    }
    
    public func recordCount(metric: Metric) {
        var counter = cachedCounters[metric.name]
        if counter == nil {
            counter = meter.counterBuilder(name: metric.name).ofDoubles().build()
            cachedCounters[metric.name] = counter
        }
        counter?.add(value: metric.value, attributes: metric.attributes)
    }
    
    public func recordIncr(metric: Metric) {
        var counter = cachedLongCounters[metric.name]
        if counter == nil {
            counter = meter.counterBuilder(name: metric.name).build()
            cachedLongCounters[metric.name] = counter
        }
        counter?.add(value: 1, attributes: metric.attributes)
    }
    
    public func recordHistogram(metric: Metric) {
        var histogram = cachedHistograms[metric.name]
        if histogram == nil {
            histogram = meter.histogramBuilder(name: metric.name).build()
            cachedHistograms[metric.name] = histogram
        }
        histogram?.record(value: metric.value, attributes: metric.attributes)
    }
    
    public func recordUpDownCounter(metric: Metric) {
        var upDownCounter = cachedUpDownCounters[metric.name]
        if upDownCounter == nil {
            upDownCounter = meter.upDownCounterBuilder(name: metric.name).ofDoubles().build()
            cachedUpDownCounters[metric.name] = upDownCounter
        }
        upDownCounter?.add(value: metric.value, attributes: metric.attributes)
    }
    
    public func flush() -> Bool {
        meterReader.forceFlush() == .success
    }
}
