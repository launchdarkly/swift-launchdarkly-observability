import Foundation
import Testing
import OpenTelemetryApi
@testable import LaunchDarklyObservability

/// Exercises the `[String: Any].toOtelAttributes()` mapping used by the `track`
/// paths (`ObservabilityService.track` / `ObjcLDObserveBridge.track`).
///
/// Scalars convert to scalar values, nested dictionaries to `.set`, arrays to
/// `.array`, and already-built attribute values are used as-is. Values with no
/// meaningful attribute form (dates, arbitrary objects) are dropped rather than
/// stringified.
struct OtelAttributesTests {

    // MARK: - Supported scalars

    @Test("converts bool / number / string members")
    func convertsScalars() {
        let source: [String: Any] = [
            "flag": true,
            "off": false,
            "count": 3,
            "rate": 2.5,
            "name": "checkout"
        ]

        let result = source.toOtelAttributes()

        #expect(result["flag"] == .bool(true))
        #expect(result["off"] == .bool(false))
        #expect(result["count"] == .int(3))
        #expect(result["rate"] == .double(2.5))
        #expect(result["name"] == .string("checkout"))
        #expect(result.count == 5)
    }

    // MARK: - Already-built attribute values are used, not skipped

    @Test("uses an already-built AttributeValue directly")
    func usesAttributeValue() {
        let source: [String: Any] = [
            "keep": "ok",
            "attr": AttributeValue.string("preconverted")
        ]

        let result = source.toOtelAttributes()

        #expect(result["keep"] == .string("ok"))
        #expect(result["attr"] == .string("preconverted"))
        #expect(result.count == 2)
    }

    @Test("nests a whole [String: AttributeValue] set under its key")
    func usesWholeAttributeSet() {
        let attributes: [String: AttributeValue] = [
            "id": .string("u-1"),
            "age": .int(30)
        ]
        let source: [String: Any] = [
            "event": "signup",
            "user": attributes
        ]

        let result = source.toOtelAttributes()

        #expect(result["event"] == .string("signup"))
        #expect(result["user"] == .set(AttributeSet(labels: [
            "id": .string("u-1"),
            "age": .int(30)
        ])))
        #expect(result.count == 2)
    }

    // MARK: - Nested map / dictionary

    @Test("nests a Map/Dictionary value as an AttributeSet")
    func nestsDictionary() {
        let source: [String: Any] = [
            "user": [
                "id": "u-1",
                "premium": true,
                "address": ["city": "SF"]
            ]
        ]

        let result = source.toOtelAttributes()

        let expected: AttributeValue = .set(AttributeSet(labels: [
            "id": .string("u-1"),
            "premium": .bool(true),
            "address": .set(AttributeSet(labels: ["city": .string("SF")]))
        ]))
        #expect(result["user"] == expected)
        #expect(result.count == 1)
    }

    // MARK: - Arrays

    @Test("converts an array value into an AttributeArray")
    func convertsArray() {
        let source: [String: Any] = ["scores": [1, 2, 3]]

        let result = source.toOtelAttributes()

        #expect(result["scores"] == .array(AttributeArray(values: [.int(1), .int(2), .int(3)])))
    }

    // MARK: - Unsupported values are dropped, never stringified

    @Test("skips dates and arbitrary objects without stringifying")
    func skipsArbitraryTypes() {
        let date = Date(timeIntervalSince1970: 0)
        let source: [String: Any] = [
            "keep": 1,
            "date": date,
            "object": NSObject()
        ]

        let result = source.toOtelAttributes()

        #expect(result["keep"] == .int(1))
        #expect(result["date"] == nil)
        #expect(result["object"] == nil)
        #expect(result["date"] != .string(String(describing: date)))
        #expect(result.count == 1)
    }

    // MARK: - NSNumber type fidelity

    @Test("maps NSNumber bool/int/double by underlying type")
    func nsNumberFidelity() {
        let source: [String: Any] = [
            "b": NSNumber(value: true),
            "i": NSNumber(value: Int(7)),
            "d": NSNumber(value: 1.5)
        ]

        let result = source.toOtelAttributes()

        #expect(result["b"] == .bool(true))
        #expect(result["i"] == .int(7))
        #expect(result["d"] == .double(1.5))
    }

    @Test("empty payload yields empty attributes")
    func emptyPayload() {
        #expect([String: Any]().toOtelAttributes().isEmpty)
    }

    // MARK: - Segment e-commerce examples from analytics-taxonomy.md (§4.2)

    @Test("Product Added flat payload")
    func productAdded() {
        let source: [String: Any] = [
            "name": "Product Added",
            "product_id": "SKU-1234",
            "quantity": 2,
            "price": 24.0,
            "currency": "USD",
            "cart_id": "cart_98f1"
        ]

        let result = source.toOtelAttributes()

        #expect(result["name"] == .string("Product Added"))
        #expect(result["product_id"] == .string("SKU-1234"))
        #expect(result["quantity"] == .int(2))
        #expect(result["price"] == .double(24.0))
        #expect(result["currency"] == .string("USD"))
        #expect(result["cart_id"] == .string("cart_98f1"))
        #expect(result.count == 6)
    }

    @Test("Checkout Started nested products payload")
    func checkoutStarted() {
        let source: [String: Any] = [
            "name": "Checkout Started",
            "order_id": "ord_5521",
            "value": 72.0,
            "currency": "USD",
            "products": [
                ["product_id": "SKU-1234", "quantity": 2, "price": 24.0],
                ["product_id": "SKU-9876", "quantity": 1, "price": 24.0]
            ]
        ]

        let result = source.toOtelAttributes()

        #expect(result["name"] == .string("Checkout Started"))
        #expect(result["order_id"] == .string("ord_5521"))
        #expect(result["value"] == .double(72.0))
        #expect(result["currency"] == .string("USD"))
        // The products array of objects nests as an array of attribute sets.
        #expect(result["products"] == .array(AttributeArray(values: [
            .set(AttributeSet(labels: [
                "product_id": .string("SKU-1234"),
                "quantity": .int(2),
                "price": .double(24.0)
            ])),
            .set(AttributeSet(labels: [
                "product_id": .string("SKU-9876"),
                "quantity": .int(1),
                "price": .double(24.0)
            ]))
        ])))
        #expect(result.count == 5)
    }
}
