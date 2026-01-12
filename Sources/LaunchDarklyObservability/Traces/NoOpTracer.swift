import OpenTelemetrySdk

struct NoOpTracer: TracesApi {
    func recordError(error: any Error, attributes: [String : OpenTelemetryApi.AttributeValue]) {}
    func startSpan(name: String, attributes: [String : OpenTelemetryApi.AttributeValue]) -> any Span {
        DefaultTracer.instance.spanBuilder(spanName: name).startSpan()
    }
    func flush() -> Bool { true}
}
