import Testing
import Foundation
@testable import LaunchDarklyObservability
import LaunchDarkly

// MARK: - toFoundation()

@Suite("LDValue.toFoundation")
struct LDValueToFoundationTests {

    @Test func null() {
        let result = LDValue.null.toFoundation()
        #expect(result is NSNull)
    }

    @Test func boolTrue() {
        let result = LDValue.bool(true).toFoundation()
        let num = result as! NSNumber
        #expect(num.boolValue == true)
    }

    @Test func boolFalse() {
        let result = LDValue.bool(false).toFoundation()
        let num = result as! NSNumber
        #expect(num.boolValue == false)
    }

    @Test func number() {
        let result = LDValue.number(3.14).toFoundation()
        let num = result as! NSNumber
        #expect(num.doubleValue == 3.14)
    }

    @Test func numberZero() {
        let result = LDValue.number(0).toFoundation()
        let num = result as! NSNumber
        #expect(num.doubleValue == 0)
    }

    @Test func numberNegative() {
        let result = LDValue.number(-42).toFoundation()
        let num = result as! NSNumber
        #expect(num.doubleValue == -42)
    }

    @Test func string() {
        let result = LDValue.string("hello").toFoundation()
        #expect((result as! NSString) as String == "hello")
    }

    @Test func stringEmpty() {
        let result = LDValue.string("").toFoundation()
        #expect((result as! NSString) as String == "")
    }

    @Test func arrayEmpty() {
        let result = LDValue.array([]).toFoundation()
        let arr = result as! NSArray
        #expect(arr.count == 0)
    }

    @Test func arrayMixed() {
        let ldArray: LDValue = .array([.bool(true), .number(1), .string("x"), .null])
        let result = ldArray.toFoundation() as! NSArray
        #expect(result.count == 4)
        #expect((result[0] as! NSNumber).boolValue == true)
        #expect((result[1] as! NSNumber).doubleValue == 1)
        #expect((result[2] as! NSString) as String == "x")
        #expect(result[3] is NSNull)
    }

    @Test func objectEmpty() {
        let result = LDValue.object([:]).toFoundation()
        let dict = result as! NSDictionary
        #expect(dict.count == 0)
    }

    @Test func objectNested() {
        let ldObj: LDValue = .object([
            "name": .string("Alice"),
            "age": .number(30),
            "active": .bool(true)
        ])
        let dict = ldObj.toFoundation() as! NSDictionary
        #expect(dict.count == 3)
        #expect((dict["name"] as! NSString) as String == "Alice")
        #expect((dict["age"] as! NSNumber).doubleValue == 30)
        #expect((dict["active"] as! NSNumber).boolValue == true)
    }

    @Test func deeplyNested() {
        let ldValue: LDValue = .object([
            "list": .array([.object(["key": .string("val")])])
        ])
        let dict = ldValue.toFoundation() as! NSDictionary
        let list = dict["list"] as! NSArray
        let inner = list[0] as! NSDictionary
        #expect((inner["key"] as! NSString) as String == "val")
    }
}

// MARK: - fromFoundation()

@Suite("LDValue.fromFoundation")
struct LDValueFromFoundationTests {

    @Test func nil_returns_null() {
        let result = LDValue.fromFoundation(nil)
        #expect(result == .null)
    }

    @Test func nsNull() {
        let result = LDValue.fromFoundation(NSNull())
        #expect(result == .null)
    }

    @Test func boolTrue() {
        let result = LDValue.fromFoundation(NSNumber(value: true))
        #expect(result == .bool(true))
    }

    @Test func boolFalse() {
        let result = LDValue.fromFoundation(NSNumber(value: false))
        #expect(result == .bool(false))
    }

    @Test func integer() {
        let result = LDValue.fromFoundation(NSNumber(value: 42))
        #expect(result == .number(42))
    }

    @Test func double() {
        let result = LDValue.fromFoundation(NSNumber(value: 2.718))
        #expect(result == .number(2.718))
    }

    @Test func string() {
        let result = LDValue.fromFoundation("world" as NSString)
        #expect(result == .string("world"))
    }

    @Test func emptyArray() {
        let result = LDValue.fromFoundation(NSArray())
        #expect(result == .array([]))
    }

    @Test func arrayOfPrimitives() {
        let arr: NSArray = [NSNumber(value: true), NSNumber(value: 5), "text" as NSString, NSNull()]
        let result = LDValue.fromFoundation(arr)
        #expect(result == .array([.bool(true), .number(5), .string("text"), .null]))
    }

    @Test func emptyDictionary() {
        let result = LDValue.fromFoundation(NSDictionary())
        #expect(result == .object([:]))
    }

    @Test func dictionary() {
        let dict: NSDictionary = ["a": NSNumber(value: 1), "b": "two" as NSString]
        let result = LDValue.fromFoundation(dict)
        #expect(result == .object(["a": .number(1), "b": .string("two")]))
    }

    @Test func nestedStructure() {
        let dict: NSDictionary = [
            "items": [NSNumber(value: true), ["nested": "value" as NSString] as NSDictionary] as NSArray
        ]
        let result = LDValue.fromFoundation(dict)
        let expected: LDValue = .object([
            "items": .array([.bool(true), .object(["nested": .string("value")])])
        ])
        #expect(result == expected)
    }

    @Test func unknownType_returns_null() {
        let result = LDValue.fromFoundation(Date())
        #expect(result == .null)
    }
}

// MARK: - Round-trip

@Suite("LDValue round-trip")
struct LDValueRoundTripTests {

    @Test(arguments: [
        LDValue.null,
        LDValue.bool(true),
        LDValue.bool(false),
        LDValue.number(0),
        LDValue.number(-99.5),
        LDValue.string(""),
        LDValue.string("hello world"),
        LDValue.array([]),
        LDValue.array([.number(1), .string("two"), .null]),
        LDValue.object([:]),
        LDValue.object(["k": .bool(false)]),
        LDValue.object(["nested": .array([.object(["deep": .number(1)])])])
    ])
    func roundTrip(original: LDValue) {
        let foundation = original.toFoundation()
        let restored = LDValue.fromFoundation(foundation)
        #expect(restored == original)
    }
}

// MARK: - Dictionary extension

@Suite("Dictionary<String, LDValue> Foundation conversion")
struct DictionaryLDValueFoundationTests {

    @Test func toFoundation() {
        let dict: [String: LDValue] = ["flag": .bool(true), "count": .number(3)]
        let ns = dict.toFoundation()
        #expect(ns.count == 2)
        #expect((ns["flag"] as! NSNumber).boolValue == true)
        #expect((ns["count"] as! NSNumber).doubleValue == 3)
    }

    @Test func fromFoundation_nil() {
        let result = [String: LDValue].fromFoundation(nil)
        #expect(result == nil)
    }

    @Test func fromFoundation_empty() {
        let result = [String: LDValue].fromFoundation(NSDictionary())
        #expect(result == nil)
    }

    @Test func fromFoundation_populated() {
        let ns: NSDictionary = ["x": NSNumber(value: true), "y": "text" as NSString]
        let result = [String: LDValue].fromFoundation(ns)!
        #expect(result["x"] == .bool(true))
        #expect(result["y"] == .string("text"))
    }

    @Test func roundTrip() {
        let original: [String: LDValue] = [
            "kind": .string("FALLTHROUGH"),
            "inExperiment": .bool(true)
        ]
        let ns = original.toFoundation()
        let restored = [String: LDValue].fromFoundation(ns)!
        #expect(restored == original)
    }
}
