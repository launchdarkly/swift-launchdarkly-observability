import Foundation
import LaunchDarkly

/// Converts between Swift LDValue (enum) and Foundation types (NSObject hierarchy)
/// so values can cross the Obj-C / MAUI boundary without JSON string parsing.
///
/// Mapping:
///   .null             <-> NSNull
///   .bool(Bool)       <-> NSNumber(value: Bool)
///   .number(Double)   <-> NSNumber(value: Double)
///   .string(String)   <-> NSString
///   .array([...])     <-> NSArray
///   .object({...})    <-> NSDictionary
extension LDValue {

    public func toFoundation() -> NSObject {
        switch self {
        case .null:
            return NSNull()
        case .bool(let b):
            return NSNumber(value: b)
        case .number(let d):
            return NSNumber(value: d)
        case .string(let s):
            return s as NSString
        case .array(let arr):
            return arr.map { $0.toFoundation() } as NSArray
        case .object(let dict):
            let ns = NSMutableDictionary(capacity: dict.count)
            for (k, v) in dict {
                ns[k] = v.toFoundation()
            }
            return ns
        }
    }

    public static func fromFoundation(_ obj: Any?) -> LDValue {
        guard let obj = obj else { return .null }
        if obj is NSNull { return .null }

        if let num = obj as? NSNumber {
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                return .bool(num.boolValue)
            }
            return .number(num.doubleValue)
        }

        if let str = obj as? String { return .string(str) }

        if let arr = obj as? [Any] {
            return .array(arr.map { fromFoundation($0) })
        }

        if let dict = obj as? [String: Any] {
            return .object(dict.mapValues { fromFoundation($0) })
        }

        return .null
    }
}

extension Dictionary where Key == String, Value == LDValue {

    public func toFoundation() -> NSDictionary {
        let ns = NSMutableDictionary(capacity: count)
        for (k, v) in self {
            ns[k] = v.toFoundation()
        }
        return ns
    }

    public static func fromFoundation(_ dict: NSDictionary?) -> [String: LDValue]? {
        guard let dict = dict, dict.count > 0 else { return nil }
        var result = [String: LDValue]()
        for (k, v) in dict {
            guard let key = k as? String else { continue }
            result[key] = LDValue.fromFoundation(v)
        }
        return result
    }
}
