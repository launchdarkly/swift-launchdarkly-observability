import Foundation
@preconcurrency import OpenTelemetryApi
@preconcurrency import OpenTelemetrySdk

extension DefaultObservabilityClient {
    public func recordError(
        _ error: Error,
        attributes: [String: AttributeValue] = [:],
        options: Span? = nil
    ) async -> Void {
        await instrumentation.recordError(error, attributes: attributes, options: options)
    }
    
    func recordLog(
        message: String,
        level: Severity,
        attributes: [String: AttributeValue]
    ) async -> Void {
        await instrumentation.recordLog(message: message, level: level, attributes: attributes)
    }
}
