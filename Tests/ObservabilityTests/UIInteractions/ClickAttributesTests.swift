import Testing
import OpenTelemetryApi
@testable import LaunchDarklyOtel
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

    @Test("an embedder-resolved click carries its element path and class name")
    func includesFunnelFields() {
        // Flutter's shape: the widget type it resolved in its own tree plus the ancestry path that
        // locates it, which no native hit-test could have produced.
        let attrs = ClickAttributes.build(
            click: ClickEvent(
                tag: "ElevatedButton",
                classname: "PrimaryButton",
                id: "checkout.pay",
                text: "Pay",
                xpath: "Scaffold/Column/ElevatedButton#checkout.pay",
                screenId: "cart-1",
                screenName: "Cart",
                x: 120,
                y: 480
            )
        )

        #expect(attrs[SemanticConvention.eventType] == .string("click"))
        #expect(attrs[SemanticConvention.eventTag] == .string("ElevatedButton"))
        #expect(attrs[SemanticConvention.eventClassname] == .string("PrimaryButton"))
        #expect(attrs[SemanticConvention.eventId] == .string("checkout.pay"))
        #expect(attrs[SemanticConvention.eventText] == .string("Pay"))
        #expect(
            attrs[SemanticConvention.eventXpath]
                == .string("Scaffold/Column/ElevatedButton#checkout.pay")
        )
        #expect(attrs[SemanticConvention.eventScreenId] == .string("cart-1"))
        #expect(attrs[SemanticConvention.eventScreenName] == .string("Cart"))
        #expect(attrs[SemanticConvention.eventX] == .int(120))
        #expect(attrs[SemanticConvention.eventY] == .int(480))
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
