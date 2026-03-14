import Foundation
import Testing
import OpenTelemetryApi
@testable import LaunchDarklyObservability

struct AttributeConverterTests {

    // MARK: - Scalar values

    @Test("converts String value")
    func stringValue() {
        let result = AttributeConverter.convertValue("hello")
        #expect(result == .string("hello"))
    }

    @Test("converts Bool value")
    func boolValue() {
        #expect(AttributeConverter.convertValue(true) == .bool(true))
        #expect(AttributeConverter.convertValue(false) == .bool(false))
    }

    @Test("converts Int value")
    func intValue() {
        let result = AttributeConverter.convertValue(42)
        #expect(result == .int(42))
    }

    @Test("converts Double value")
    func doubleValue() {
        let result = AttributeConverter.convertValue(3.14)
        #expect(result == .double(3.14))
    }

    // MARK: - Unsupported / fallback

    @Test("falls back to string for unsupported types")
    func unsupportedFallback() {
        let date = Date(timeIntervalSince1970: 0)
        let result = AttributeConverter.convertValue(date)
        #expect(result == .string(String(describing: date)))
    }

    // MARK: - NSDictionary (nested)

    @Test("converts NSDictionary to AttributeSet")
    func nsDictionary() {
        let nsDict: NSDictionary = ["key": "value"]
        let result = AttributeConverter.convertValue(nsDict)
        let expected: AttributeValue = .set(AttributeSet(labels: ["key": .string("value")]))
        #expect(result == expected)
    }

    @Test("converts nested NSDictionary recursively")
    func nestedNSDictionary() {
        let inner: NSDictionary = ["b": 2]
        let outer: NSDictionary = ["a": inner]
        let result = AttributeConverter.convertValue(outer)
        let expected: AttributeValue = .set(AttributeSet(labels: [
            "a": .set(AttributeSet(labels: ["b": .int(2)]))
        ]))
        #expect(result == expected)
    }

    @Test("converts empty NSDictionary to empty AttributeSet")
    func emptyNSDictionary() {
        let nsDict: NSDictionary = [:]
        let result = AttributeConverter.convertValue(nsDict)
        #expect(result == .set(AttributeSet(labels: [:])))
    }

    // MARK: - NSArray

    @Test("converts NSArray of NSNumber (int) to array of int AttributeValues")
    func nsArrayOfInts() {
        let nsArr: NSArray = [NSNumber(value: 1), NSNumber(value: 2), NSNumber(value: 3)]
        let result = AttributeConverter.convertValue(nsArr)
        let expected: AttributeValue = .array(AttributeArray(values: [.int(1), .int(2), .int(3)]))
        #expect(result == expected)
    }

    @Test("converts NSArray of NSString to array of string AttributeValues")
    func nsArrayOfStrings() {
        let nsArr: NSArray = ["a" as NSString, "b" as NSString]
        let result = AttributeConverter.convertValue(nsArr)
        let expected: AttributeValue = .array(AttributeArray(values: [.string("a"), .string("b")]))
        #expect(result == expected)
    }

    @Test("converts empty NSArray to empty AttributeArray")
    func emptyNSArray() {
        let nsArr: NSArray = []
        let result = AttributeConverter.convertValue(nsArr)
        #expect(result == .array(AttributeArray(values: [])))
    }

    // MARK: - NSDictionary containing NSArray

    @Test("converts NSDictionary containing NSArray")
    func nsDictionaryWithArray() {
        let nsDict: NSDictionary = [
            "items": [NSNumber(value: 10), NSNumber(value: 20)] as NSArray
        ]
        let result = AttributeConverter.convertValue(nsDict)
        let expected: AttributeValue = .set(AttributeSet(labels: [
            "items": .array(AttributeArray(values: [.int(10), .int(20)]))
        ]))
        #expect(result == expected)
    }

    // MARK: - Full dictionary conversion

    @Test("converts flat [String: Any] dictionary")
    func flatDictionary() {
        let source: [String: Any] = [
            "name": "test",
            "count": 5,
            "rate": 1.5,
            "enabled": true
        ]
        let result = AttributeConverter.convert(source)
        #expect(result["name"] == .string("test"))
        #expect(result["count"] == .int(5))
        #expect(result["rate"] == .double(1.5))
        #expect(result["enabled"] == .bool(true))
    }

    @Test("converts empty dictionary")
    func emptyDictionary() {
        let result = AttributeConverter.convert([:])
        #expect(result.isEmpty)
    }

    // MARK: - MAUI sample payload

    @Test("converts the MAUI sample nested payload end-to-end")
    func mauiSamplePayload() {
        let innerArray: NSArray = [NSNumber(value: Int32(1))]
        let innerDict: NSDictionary = ["array": innerArray]
        let source: [String: Any] = [
            "test-log": "maui",
            "nested": innerDict
        ]

        let result = AttributeConverter.convert(source)

        #expect(result["test-log"] == .string("maui"))

        let nestedExpected: AttributeValue = .set(AttributeSet(labels: [
            "array": .array(AttributeArray(values: [.int(1)]))
        ]))
        #expect(result["nested"] == nestedExpected)
    }

    // MARK: - Deeply nested structure

    @Test("converts deeply nested structure")
    func deeplyNested() {
        let level3: NSDictionary = ["value": NSNumber(value: 42)]
        let level2: NSDictionary = ["level3": level3]
        let level1: NSDictionary = ["level2": level2]
        let source: [String: Any] = ["level1": level1]

        let result = AttributeConverter.convert(source)

        let expected: AttributeValue = .set(AttributeSet(labels: [
            "level2": .set(AttributeSet(labels: [
                "level3": .set(AttributeSet(labels: [
                    "value": .int(42)
                ]))
            ]))
        ]))
        #expect(result["level1"] == expected)
    }
}
