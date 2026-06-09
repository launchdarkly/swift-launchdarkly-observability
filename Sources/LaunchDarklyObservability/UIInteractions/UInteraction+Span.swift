import Foundation
import OSLog

extension TouchInteraction {
    func startEndSpan(tracer: Tracer, log: OSLog) {
        guard case let .touchUp(point) = kind else { return }

        // Per analytics-taxonomy §4.1 `click`: one event for all element types,
        // described through the `event.*` namespace.
        var attributes: [String: AttributeValue] = [:]
        attributes[SemanticConvention.eventType] = .string(SemanticConvention.clickSpanName)
        attributes[SemanticConvention.eventTag] = .string(target?.className ?? "unknown")
        if let accessibilityIdentifier = target?.accessibilityIdentifier {
            attributes[SemanticConvention.eventId] = .string(accessibilityIdentifier)
        }
        if let text = target?.text {
            attributes[SemanticConvention.eventText] = .string(text)
        }
        attributes[SemanticConvention.eventX] = .int(Int(point.x))
        attributes[SemanticConvention.eventY] = .int(Int(point.y))

        let span = tracer.startSpan(name: SemanticConvention.clickSpanName,
                                    attributes: attributes,
                                    startTime: Date(timeIntervalSince1970: startTimestamp))
        span.end(time: Date(timeIntervalSince1970: timestamp))

        #if DEBUG
        logClickSpanShape(name: SemanticConvention.clickSpanName, attributes: attributes, log: log)
        #endif
    }

    #if DEBUG
    /// Logs the JSON shape of the OTel `click` span (name + `event.*` attributes) for debugging.
    private func logClickSpanShape(name: String, attributes: [String: AttributeValue], log: OSLog) {
        var jsonAttributes: [String: Any] = [:]
        for (key, value) in attributes {
            switch value {
            case .string(let s): jsonAttributes[key] = s
            case .int(let i): jsonAttributes[key] = i
            case .double(let d): jsonAttributes[key] = d
            case .bool(let b): jsonAttributes[key] = b
            default: jsonAttributes[key] = String(describing: value)
            }
        }
        let shape: [String: Any] = ["span": name, "attributes": jsonAttributes]
        guard let data = try? JSONSerialization.data(withJSONObject: shape, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return }
        os_log("%{public}@", log: log, type: .debug, "[Otel Click] \(json)")
    }
    #endif
}
