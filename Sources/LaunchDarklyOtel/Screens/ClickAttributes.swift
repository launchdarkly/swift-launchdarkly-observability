import Foundation

/// Builds the `event.*` attributes for a `click` span (taxonomy §4.1), shared by every click path
/// through ``ObservabilityService/recordClick(_:)``. Applied in increasing precedence so the
/// taxonomy can never be clobbered: caller `properties` first, then `contextKeyAttributes`, then the
/// reserved `event.*` fields last. Optional values are omitted when `nil`; `event.type` is always
/// present.
public enum ClickAttributes {
    public static func build(
        id: String?,
        tag: String?,
        text: String?,
        screenId: String?,
        screenName: String? = nil,
        x: Int?,
        y: Int?,
        classname: String? = nil,
        xpath: String? = nil,
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
        if let classname {
            attributes[SemanticConvention.eventClassname] = .string(classname)
        }
        if let id {
            attributes[SemanticConvention.eventId] = .string(id)
        }
        if let text {
            attributes[SemanticConvention.eventText] = .string(text)
        }
        if let xpath {
            attributes[SemanticConvention.eventXpath] = .string(xpath)
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

    /// Builds the span attributes for `click`, the shape carried by the click funnel.
    public static func build(
        click: ClickEvent,
        contextKeyAttributes: [String: AttributeValue] = [:],
        properties: [String: AttributeValue] = [:]
    ) -> [String: AttributeValue] {
        build(
            id: click.id,
            tag: click.tag,
            text: click.text,
            screenId: click.screenId,
            screenName: click.screenName,
            x: click.x,
            y: click.y,
            classname: click.classname,
            xpath: click.xpath,
            contextKeyAttributes: contextKeyAttributes,
            properties: properties
        )
    }
}
