import Testing
import OpenTelemetryApi
@testable import LaunchDarklyObservability

/// Unit tests for the shared `click` attribute builder used by the manual `trackClick` API
/// (taxonomy §4.1).
struct ClickAttributesTests {
    @Test("manual click shape includes the supplied event.* fields")
    func includesSuppliedFields() {
        let attrs = ClickAttributes.build(
            id: "paywall.primary_cta",
            tag: "UIButton",
            text: "Continue",
            screenId: "MyApp.PaywallViewController",
            x: 120,
            y: 818
        )

        #expect(attrs[SemanticConvention.eventType] == .string("click"))
        #expect(attrs[SemanticConvention.eventTag] == .string("UIButton"))
        #expect(attrs[SemanticConvention.eventId] == .string("paywall.primary_cta"))
        #expect(attrs[SemanticConvention.eventText] == .string("Continue"))
        #expect(attrs[SemanticConvention.eventScreenId] == .string("MyApp.PaywallViewController"))
        #expect(attrs[SemanticConvention.eventX] == .int(120))
        #expect(attrs[SemanticConvention.eventY] == .int(818))
    }

    @Test("optional fields are omitted when nil")
    func omitsNilFields() {
        let attrs = ClickAttributes.build(
            id: nil,
            tag: nil,
            text: nil,
            screenId: nil,
            x: nil,
            y: nil
        )

        // event.type is always present; everything else is omitted.
        #expect(attrs[SemanticConvention.eventType] == .string("click"))
        #expect(attrs[SemanticConvention.eventTag] == nil)
        #expect(attrs[SemanticConvention.eventId] == nil)
        #expect(attrs[SemanticConvention.eventText] == nil)
        #expect(attrs[SemanticConvention.eventScreenId] == nil)
        #expect(attrs[SemanticConvention.eventX] == nil)
        #expect(attrs[SemanticConvention.eventY] == nil)
    }

    @Test("reserved event.* fields win over caller properties")
    func reservedFieldsWin() {
        let properties: [String: AttributeValue] = [
            SemanticConvention.eventId: .string("from_properties"),
            SemanticConvention.eventType: .string("not_click"),
            "custom": .string("kept")
        ]

        let attrs = ClickAttributes.build(
            id: "reserved_id",
            tag: nil,
            text: nil,
            screenId: nil,
            x: nil,
            y: nil,
            properties: properties
        )

        #expect(attrs[SemanticConvention.eventId] == .string("reserved_id"))
        #expect(attrs[SemanticConvention.eventType] == .string("click"))
        #expect(attrs["custom"] == .string("kept"))
    }

    @Test("context keys win over caller properties")
    func contextKeysWinOverProperties() {
        let properties: [String: AttributeValue] = ["accountId": .string("from_properties")]
        let contextKeys: [String: AttributeValue] = ["accountId": .string("from_context")]

        let attrs = ClickAttributes.build(
            id: nil,
            tag: nil,
            text: nil,
            screenId: nil,
            x: nil,
            y: nil,
            contextKeyAttributes: contextKeys,
            properties: properties
        )

        #expect(attrs["accountId"] == .string("from_context"))
    }
}
