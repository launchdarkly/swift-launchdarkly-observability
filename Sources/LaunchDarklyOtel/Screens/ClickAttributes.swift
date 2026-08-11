import Foundation

/// Builds the `event.*` attributes for a `click` span (taxonomy §4.1), shared by the manual
/// `trackClick` API. Applied in increasing precedence so the taxonomy can never be clobbered:
/// caller `properties` first, then `contextKeyAttributes`, then the reserved `event.*` fields
/// last. Optional values are omitted when `nil`; `event.type` is always present.
public enum ClickAttributes {
    public static func build(
        id: String?,
        tag: String?,
        text: String?,
        screenId: String?,
        screenName: String? = nil,
        x: Int?,
        y: Int?,
        contextKeyAttributes: [String: AttributeValue] = [:],
        properties: [String: AttributeValue] = [:]
    ) -> [String: AttributeValue] {
        var attributes: [String: AttributeValue] = [:]
        for (k, v) in properties {
            attributes[k] = v
        }
        for (k, v) in contextKeyAttributes {
            attributes[k] = v
        }
        attributes[SemanticConvention.eventType] = .string(SemanticConvention.clickSpanName)
        if let tag {
            attributes[SemanticConvention.eventTag] = .string(tag)
        }
        if let id {
            attributes[SemanticConvention.eventId] = .string(id)
        }
        if let text {
            attributes[SemanticConvention.eventText] = .string(text)
        }
        if let screenId {
            attributes[SemanticConvention.eventScreenId] = .string(screenId)
        }
        if let screenName {
            attributes[SemanticConvention.eventScreenName] = .string(screenName)
        }
        if let x {
            attributes[SemanticConvention.eventX] = .int(x)
        }
        if let y {
            attributes[SemanticConvention.eventY] = .int(y)
        }
        return attributes
    }
}
