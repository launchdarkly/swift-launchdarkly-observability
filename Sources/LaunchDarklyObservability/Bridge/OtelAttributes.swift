import Foundation
import OpenTelemetryApi

extension Dictionary where Key == String, Value == Any {
    /// Converts a `track` event's `data` payload into OTel attributes.
    ///
    /// Structure is preserved: scalars map to scalar values, nested dictionaries
    /// to `.set`, arrays to `.array`, and an already-built `AttributeValue` (or a
    /// whole `[String: AttributeValue]` set) is used as-is. Any value that has no
    /// meaningful attribute form (e.g. a `Date` or an arbitrary object) is
    /// skipped — never stringified.
    func toOtelAttributes() -> [String: AttributeValue] {
        var result: [String: AttributeValue] = [:]
        for (key, value) in self {
            if let converted = Self.attributeValue(from: value) {
                result[key] = converted
            }
        }
        return result
    }

    private static func attributeValue(from value: Any) -> AttributeValue? {
        // Already an attribute value, or a whole attribute set: use directly.
        if let attributeValue = value as? AttributeValue { return attributeValue }
        if let labels = value as? [String: AttributeValue] {
            return .set(AttributeSet(labels: labels))
        }

        // Nested dictionary -> nested attribute set.
        if let nsDict = value as? NSDictionary {
            var labels: [String: AttributeValue] = [:]
            for (rawKey, nestedValue) in nsDict {
                if let key = rawKey as? String, let converted = attributeValue(from: nestedValue) {
                    labels[key] = converted
                }
            }
            return .set(AttributeSet(labels: labels))
        }

        // Array -> attribute array, dropping elements that can't be represented.
        if let nsArray = value as? NSArray {
            return .array(AttributeArray(values: nsArray.compactMap { attributeValue(from: $0) }))
        }

        // NSNumber covers values bridged from the Obj-C/pigeon bridge and, on
        // Apple platforms, native Swift Bool/Int/Double (which bridge to NSNumber).
        // objCType disambiguates bool vs numeric so an NSNumber(0/1) is not misread
        // as a Bool (and vice versa).
        if let number = value as? NSNumber {
            switch String(cString: number.objCType) {
            case "c", "B": return .bool(number.boolValue)
            case "d", "f": return .double(number.doubleValue)
            default: return .int(number.intValue)
            }
        }

        if let string = value as? String { return .string(string) }

        // Explicit native Swift scalars as a guaranteed fallback, in case a value
        // is not NSNumber-bridged. Kept after the NSNumber branch so a bridged
        // NSNumber(0/1) keeps its numeric/bool identity rather than matching `Bool`.
        if let boolValue = value as? Bool { return .bool(boolValue) }
        if let intValue = value as? Int { return .int(intValue) }
        if let doubleValue = value as? Double { return .double(doubleValue) }

        // Date, arbitrary objects, etc.: dropped rather than stringified.
        return nil
    }
}
