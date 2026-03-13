import Foundation
import OpenTelemetryApi

/// Converts Foundation types (from Obj-C bridge) into OpenTelemetry `AttributeValue`.
///
/// Values arriving from a .NET MAUI / Obj-C bridge are Foundation types
/// (`NSString`, `NSNumber`, `NSDictionary`, `NSArray`).
/// `AttributeValue.init?(Any)` does not handle Foundation collection types,
/// so this converter checks for `NSDictionary` / `NSArray` explicitly and
/// recurses into nested structures.
enum AttributeConverter {

    /// Converts a `[String: Any]` dictionary of Foundation values into
    /// `[String: AttributeValue]`.
    static func convert(_ source: [String: Any]) -> [String: AttributeValue] {
        var result: [String: AttributeValue] = [:]
        for (key, value) in source {
            result[key] = convertValue(value)
        }
        return result
    }

    /// Converts a single Foundation value into an `AttributeValue`.
    ///
    /// Resolution order:
    /// 1. `NSDictionary`  → `.set(AttributeSet(labels: …))` (recursive)
    /// 2. `NSArray`       → `.array(AttributeArray(values: …))` (recursive)
    /// 3. `NSNumber`      → `.bool` / `.int` / `.double` based on `objCType`
    ///    (avoids Swift's special bridging that converts NSNumber(0/1) to Bool)
    /// 4. `String`        → `.string`
    /// 5. Fallback        → `.string(String(describing: value))`
    static func convertValue(_ value: Any) -> AttributeValue {
        if let nsDict = value as? NSDictionary {
            var labels: [String: AttributeValue] = [:]
            for (key, val) in nsDict {
                if let strKey = key as? String {
                    labels[strKey] = convertValue(val)
                }
            }
            return .set(AttributeSet(labels: labels))
        }

        if let nsArr = value as? NSArray {
            var values: [AttributeValue] = []
            for item in nsArr {
                values.append(convertValue(item))
            }
            return .array(AttributeArray(values: values))
        }

        // Handle NSNumber before AttributeValue.init?(Any) to avoid Swift's
        // special Bool bridging: the runtime converts NSNumber(0) and NSNumber(1)
        // to Bool regardless of the original numeric type.
        if let nsNum = value as? NSNumber {
            switch String(cString: nsNum.objCType) {
            case "c", "B":
                return .bool(nsNum.boolValue)
            case "d", "f":
                return .double(nsNum.doubleValue)
            default:
                return .int(nsNum.integerValue)
            }
        }

        if let s = value as? String {
            return .string(s)
        }

        return .string(String(describing: value))
    }
}
