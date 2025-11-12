final class AppTraceClient: TracesApi {
    private let options: Options.AppTracing
    private let tracingApiClient: TracesApi
    
    init(
        options: Options.AppTracing,
        tracingApiClient: TracesApi
    ) {
        self.options = options
        self.tracingApiClient = tracingApiClient
    }
    
    func recordError(error: Error, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        guard options.includeErrors else { return }
        tracingApiClient.recordError(error: error, attributes: attributes)
    }
    
    func startSpan(name: String, attributes: [String : OpenTelemetryApi.AttributeValue]) -> any OpenTelemetryApi.Span {
        guard options.includeSpans else {
            return OpenTelemetry.instance.tracerProvider
                .get(instrumentationName: "")
                .spanBuilder(spanName: "")
                .startSpan()
        }
        return tracingApiClient.startSpan(name: name, attributes: attributes)
    }
}
