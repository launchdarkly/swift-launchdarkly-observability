@preconcurrency import OpenTelemetrySdk
@preconcurrency import OpenTelemetryApi

extension DefaultObservabilityClient {
    public func startSpan(name: String, attributes: [String: AttributeValue]? = nil) async -> Span {
        await instrumentation.startSpan(name: name, attributes: attributes)
    }
    
    public func startActiveSpan<T>(
        name: String,
        fn: @Sendable (any OpenTelemetryApi.SpanBase) async throws -> T,
        attributes: [String : OpenTelemetryApi.AttributeValue]?
    ) async throws -> T where T : Sendable {
        try await instrumentation.startActiveSpan(name: name, fn: fn, attributes: attributes)
    }
}
