/*
import Foundation
@preconcurrency import OpenTelemetryApi

public enum LogLevel: String {
    case debug, info, warning, error, critical
}

private let logMessageEncoder = JSONEncoder()

extension InstrumentationManager {
    private static let errorSpanName = "error"
    
    public func recordError(
        _ error: Error,
        attributes: [String: AttributeValue] = [:],
        options: (() -> Span)? = nil
    ) async -> Void {
        let currentSpan = await activeSpan()
        let activeSpan = options?() ?? currentSpan
        let span = activeSpan ?? tracer().spanBuilder(spanName: InstrumentationManager.errorSpanName).startSpan()
        let sessionId = await sessionId()
        
        span.recordException(error)
        
        span.setAttribute(key: SemanticAttributes.exceptionMessage, value: error.localizedDescription)
        // TODO: define what to use instead of error.name
        span.setAttribute(key: SemanticAttributes.type, value: "No name" )
        let stackSymbols = Thread.callStackSymbols.joined(separator: "\n")
        if stackSymbols.isEmpty == false {
            span.setAttribute(key: SemanticAttributes.exceptionStacktrace, value: stackSymbols)
        }
        
        if sessionId.isEmpty == false {
            span.setAttribute(key: "highlight.session_id", value: sessionId)
        }
        span.status = .error(description: error.localizedDescription)
        span.setAttributes(attributes)
        
        activeSpan?.end()
        
        await  recordLog(
            message: error.localizedDescription,
            level: .error,
            attributes: [
                SemanticAttributes.type.rawValue: .string("No name"),
                SemanticAttributes.exceptionMessage.rawValue: .string(error.localizedDescription),
                SemanticAttributes.exceptionStacktrace.rawValue: .string(stackSymbols)
            ]
        )
    }
    
    
    public func recordLog<T>(
        message: T,
        level: Severity,
        attributes: [String: AttributeValue] = [:]
    ) async -> Void where T: Encodable {
        do {
            logMessageEncoder.outputFormatting = [.prettyPrinted]
            let jsonData = try logMessageEncoder.encode(message)
            guard let message = String(data: jsonData, encoding: .utf8) else {
                throw URLError(.cannotParseResponse)
            }
            await self.recordLog(message: message, level: level, attributes: attributes)
        } catch {
            print("Failed to record log: \(error)")
        }
    }
    
    public func recordLog(
        message: String,
        level: Severity,
        attributes: [String: AttributeValue] = [:]
    ) async -> Void {
        let logger = self.logger()
        
        var attributes = attributes
        let sessionId = await sessionId()
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
*/
