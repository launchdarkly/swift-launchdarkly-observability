import OpenTelemetryApi
import OpenTelemetrySdk

struct MetricsApiFactory {
    static func make(options: Options, namespace: String? = nil, reader: MetricReader) -> MetricsApi {
        var resourceAttributes = options.resourceAttributes
        if let namespace {
            resourceAttributes[SemanticConvention.serviceNamespace] = .string(namespace)
        }
        let provider = MeterProviderSdk.builder()
            .setResource(resource: .init(attributes: resourceAttributes))
            .registerView(
                selector: InstrumentSelector
                    .builder()
                    .setInstrument(name: ".*")
                    .build(),
                view: View
                    .builder()
                    .withAggregation(aggregation: Aggregations.defaultAggregation())
                    .build()
            )
            .registerMetricReader(
                reader: reader
            )
            .build()
        
        let meter = provider.get(name: options.serviceName)
        return MeterFacade(
            options: options,
            meter: meter,
            flush: {
                reader.forceFlush() == .success
            }
        )
    }
}
