@preconcurrency import OpenTelemetryApi
import OpenTelemetrySdk
import StdoutExporter
import OpenTelemetryProtocolExporterHttp

public struct LoggerFacade {
    private let configuration: Configuration
    public var logger: Logger {
        OpenTelemetry.instance.loggerProvider.get(
            instrumentationScopeName: configuration.serviceName
        )
    }
    
    public init(configuration: Configuration) {
        self.configuration = configuration
        OpenTelemetry.registerLoggerProvider(
            loggerProvider: buildLoggerProvider(using: Resource(attributes: configuration.resourceAttributes))
        )
    }
    
    private func buildExporter(using configuration: Configuration) -> LogRecordExporter {
        var logRecordExporters = [any LogRecordExporter]()
        
        if let httpExporter = buildHttpExporter(using: configuration) {
            logRecordExporters.append(httpExporter)
        }
        
        if configuration.isDebug {
            logRecordExporters.append(
                StdoutLogExporter(isDebug: configuration.isDebug)
            )
        }
        
        return MultiLogRecordExporter(logRecordExporters: logRecordExporters)
    }
    
    private func buildHttpExporter(using configuration: Configuration) -> (OtlpHttpExporterBase & LogRecordExporter)? {
        guard let baseUrl = URL(string: configuration.otlpEndpoint) else {
            print("Trace exporter URL is invalid")
            return nil
        }
        let url = baseUrl.appending(path: HttpExporterPath.logs)
        return OtlpHttpLogExporter(
            endpoint: url,
            envVarHeaders: configuration.customHeaders
        )
    }
    
    private func buildLoggerProvider(using resource: Resource) -> LoggerProvider {
        LoggerProviderBuilder()
            .with(
                processors: [
                    BatchLogRecordProcessor(
                        logRecordExporter: buildExporter(using: configuration)
                    )
                ]
            )
            .with(resource: Resource(attributes: configuration.resourceAttributes))
            .build()
    }
    
    // MARK: - Public API
    
    public func eventProvider() -> LogRecordBuilder {
        logger.logRecordBuilder()
    }
}
