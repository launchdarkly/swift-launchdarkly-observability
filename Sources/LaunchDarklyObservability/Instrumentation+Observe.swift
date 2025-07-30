import Foundation
@preconcurrency import OpenTelemetryApi
@preconcurrency import OpenTelemetrySdk

extension DefaultInstrumentation {
    private enum SpanKey {
        static let errorSpanName = "error"
    }

    public func recordError(
        _ error: Error,
        attributes: [String: AttributeValue] = [:],
        options: Span? = nil
    ) async -> Void {
        let currentSpan = OpenTelemetry.instance.contextProvider.activeSpan
        let activeSpan = options ?? currentSpan
        let span = activeSpan ?? tracer().spanBuilder(spanName: SpanKey.errorSpanName).startSpan()
        let sessionId = await sessionInfo().sessionId
        
        span.recordException(error)
        
        span.setAttribute(key: SemanticAttributes.exceptionMessage, value: String(describing: error))
        span.setAttribute(key: SemanticAttributes.type, value: String(describing: error))
        let stackSymbols = Thread.callStackSymbols.joined(separator: "\n")
        if stackSymbols.isEmpty == false {
            span.setAttribute(key: SemanticAttributes.exceptionStacktrace, value: stackSymbols)
        }
        
        if sessionId.isEmpty == false {
            span.setAttribute(
                key: AttributeKey.sessionId.rawValue,
                value: sessionId
            )
        }
        span.status = .error(description: String(describing: error))
        span.setAttributes(attributes)
        
        activeSpan?.end()
        
        await  recordLog(
            message: error.localizedDescription,
            level: .error,
            attributes: [
                SemanticAttributes.type.rawValue: .string(String(describing: error)),
                SemanticAttributes.exceptionMessage.rawValue: .string(String(describing: error)),
                SemanticAttributes.exceptionStacktrace.rawValue: .string(stackSymbols)
            ]
        )
    }
    
    public func recordLog(
        message: String,
        level: Severity,
        attributes: [String: AttributeValue] = [:]
    ) async -> Void {
        let logger = self.logger()
        
        var attributes = attributes
        let sessionId = await sessionInfo().sessionId
        attributes["log.source"] = .string("swift-obsevability-sdk")
        attributes["highlight.session_id"] = .string(sessionId)
        logger
            .logRecordBuilder()
            .setSeverity(level)
            .setBody(.string(message))
            .setAttributes(attributes)
            .setTimestamp(.now)
            .emit()
    }
}
