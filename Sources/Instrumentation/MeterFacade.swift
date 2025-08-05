@preconcurrency import OpenTelemetryApi
import OpenTelemetrySdk
import StdoutExporter
import OpenTelemetryProtocolExporterHttp

public struct MeterFacade {
    private let configuration: Configuration
    public var meter: Meter {
        OpenTelemetry.instance.meterProvider.get(
            instrumentationName: configuration.serviceName,
            instrumentationVersion: configuration.serviceVersion
        )
    }
    
    public init(configuration: Configuration) {
        self.configuration = configuration
        OpenTelemetry.registerStableMeterProvider(
            meterProvider: buildMeterProvider(using: configuration)
        )
    }
    
    private func buildExporter(using configuration: Configuration) -> StableMetricExporter {
        var metricExporters = [any StableMetricExporter]()
        
        if let httpExporter = buildHttpExporter(using: configuration) {
            metricExporters.append(httpExporter)
        }
        
        if configuration.isDebug {
            metricExporters.append(
                StdoutMetricExporter(isDebug: configuration.isDebug)
            )
        }
        // TODO: figure out how to use a multi exporter like in tracer and logger, for now, using the http exporter
        return metricExporters[0]
    }
    
    private func buildHttpExporter(using configuration: Configuration) -> (StableMetricExporter)? {
        guard let baseUrl = URL(string: configuration.otlpEndpoint) else {
            print("Trace exporter URL is invalid")
            return nil
        }
        let url = baseUrl.appending(path: HttpExporterPath.metrics)
        return StableOtlpHTTPMetricExporter(
            endpoint: url,
            envVarHeaders: configuration.customHeaders
        )
    }
    
    private func buildReader(using exporter: StableMetricExporter) -> StableMetricReader {
        StablePeriodicMetricReaderBuilder(exporter: exporter)
            .setInterval(timeInterval: 60.0)
            .build()
    }
    
    private func buildMeterProvider(using configuration: Configuration) -> any StableMeterProvider {
        StableMeterProviderSdk.builder()
            .registerView(
                selector: InstrumentSelector.builder().setInstrument(name: configuration.serviceName).build(),
                view: StableView.builder().build()
            )
            .registerMetricReader(
                reader: buildReader(
                    using: buildExporter(using: configuration)
                )
            )
            .build()
    }
    
    // MARK: - Public API
    
}
