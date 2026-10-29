import OpenTelemetryApi
#if !LD_COCOAPODS
    import Common
#endif

final class MetricsClient {
    private let options: ObservabilityOptions
    private let meter: any Meter
    private let flushMetrics: () -> Bool
    private let globalAttributes: GlobalAttributesStore
    private var cachedGauges = AtomicDictionary<String, DoubleGauge>()
    private var cachedCounters = AtomicDictionary<String, DoubleCounter>()
    private var cachedLongCounters = AtomicDictionary<String, LongCounter>()
    private var cachedHistograms = AtomicDictionary<String, DoubleHistogram>()
    private var cachedUpDownCounters = AtomicDictionary<String, DoubleUpDownCounter>()
    
    init(
        options: ObservabilityOptions,
        meter: any Meter,
        globalAttributes: GlobalAttributesStore = .shared,
        flush: @escaping () -> Bool
    ) {
        self.options = options
        self.meter = meter
        self.globalAttributes = globalAttributes
        self.flushMetrics = flush
    }

    private func attributes(of metric: Metric) -> [String: AttributeValue] {
        globalAttributes.filling(metric.attributes)
    }
}

extension MetricsClient: MetricsApi {
    public func recordMetric(metric: Metric) {
        var gauge = cachedGauges[metric.name]
        if gauge == nil {
            gauge = meter
                .gaugeBuilder(name: metric.name)
                .build()
            cachedGauges[metric.name] = gauge
        }
        gauge?.record(value: metric.value, attributes: attributes(of: metric))
    }
    
    public func recordCount(metric: Metric) {
        var counter = cachedCounters[metric.name]
        if counter == nil {
            counter = meter.counterBuilder(name: metric.name).ofDoubles().build()
            cachedCounters[metric.name] = counter
        }
        counter?.add(value: metric.value, attributes: attributes(of: metric))
    }
    
    public func recordIncr(metric: Metric) {
        var counter = cachedLongCounters[metric.name]
        if counter == nil {
            counter = meter.counterBuilder(name: metric.name).build()
            cachedLongCounters[metric.name] = counter
        }
        counter?.add(value: 1, attributes: attributes(of: metric))
    }
    
    public func recordHistogram(metric: Metric) {
        var histogram = cachedHistograms[metric.name]
        if histogram == nil {
            histogram = meter.histogramBuilder(name: metric.name).build()
            cachedHistograms[metric.name] = histogram
        }
        histogram?.record(value: metric.value, attributes: attributes(of: metric))
    }
    
    public func recordUpDownCounter(metric: Metric) {
        var upDownCounter = cachedUpDownCounters[metric.name]
        if upDownCounter == nil {
            upDownCounter = meter.upDownCounterBuilder(name: metric.name).ofDoubles().build()
            cachedUpDownCounters[metric.name] = upDownCounter
        }
        upDownCounter?.add(value: metric.value, attributes: attributes(of: metric))
    }
    
    public func flush() -> Bool {
        self.flushMetrics()
    }
}
