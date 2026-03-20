import Foundation
import OpenTelemetryApi

/// @objc wrapper around a live OpenTelemetry ``Span``.
///
/// Created by ``ObjcTracer/spanBuilder(name:startTime:)`` and held
/// by the C# side until all attributes / status are set, then
/// finalized with ``end(time:)``.
@objc(ObjcSpanBuilder)
public final class ObjcSpanBuilder: NSObject {
    private let span: any Span

    init(span: any Span) {
        self.span = span
        super.init()
    }

    // MARK: - Context

    @objc public var traceId: String {
        span.context.traceId.hexString
    }

    @objc public var spanId: String {
        span.context.spanId.hexString
    }

    /// SpanKind as int: 0 = internal, 1 = server, 2 = client, 3 = producer, 4 = consumer
    @objc public var spanKind: Int {
        switch span.kind {
        case .internal: return 0
        case .server:   return 1
        case .client:   return 2
        case .producer: return 3
        case .consumer: return 4
        @unknown default: return 0
        }
    }

    // MARK: - Attributes

    @objc(setAttributeWithKey:value:)
    public func setAttribute(key: String, value: NSObject) {
        span.setAttribute(key: key, value: convertToAttributeValue(value))
    }

    @objc(setAttributes:)
    public func setAttributes(_ attributes: NSDictionary) {
        let attrs = AttributeConverter.convert(
            (attributes as? [String: Any]) ?? [:]
        )
        span.setAttributes(attrs)
    }

    // MARK: - Events

    @objc(addEventWithName:)
    public func addEvent(name: String) {
        span.addEvent(name: name)
    }

    @objc(addEventWithName:attributes:)
    public func addEvent(name: String, attributes: NSDictionary) {
        let attrs = AttributeConverter.convert(
            (attributes as? [String: Any]) ?? [:]
        )
        span.addEvent(name: name, attributes: attrs)
    }

    // MARK: - Exceptions

    @objc(recordExceptionWithMessage:type:)
    public func recordException(message: String, type: String) {
        let error = NSError(
            domain: type,
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        span.recordException(error)
    }

    @objc(recordExceptionWithMessage:type:attributes:)
    public func recordException(message: String, type: String, attributes: NSDictionary) {
        let error = NSError(
            domain: type,
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        let attrs = AttributeConverter.convert(
            (attributes as? [String: Any]) ?? [:]
        )
        span.recordException(error, attributes: attrs)
    }

    // MARK: - Status & End

    @objc(setStatusCode:)
    public func setStatus(code: Int) {
        switch code {
        case 1:  span.status = .ok
        case 2:  span.status = .error(description: "")
        default: break
        }
    }

    @objc(endWithTime:)
    public func end(time: Double) {
        span.end(time: Date(timeIntervalSince1970: time))
    }

    // MARK: - Helpers

    private func convertToAttributeValue(_ value: NSObject) -> AttributeValue {
        switch value {
        case let s as NSString:
            return .string(s as String)
        case let n as NSNumber:
            switch String(cString: n.objCType) {
            case "c", "B": return .bool(n.boolValue)
            case "d", "f": return .double(n.doubleValue)
            default:        return .int(n.intValue)
            }
        default:
            return .string(String(describing: value))
        }
    }
}
