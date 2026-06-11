import Foundation
import OpenTelemetryApi

/// Converts Foundation / Swift values into OpenTelemetry `AttributeValue`s.
///
/// Values reach this converter from several sources: the LD `track` hook
/// (`LDValue` bridged to Foundation), the manual `LDObserve` track/log/span
/// APIs (`[String: Any]`), and the Obj-C / .NET MAUI bridge (`NSString`,
/// `NSNumber`, `NSDictionary`, `NSArray`). `AttributeValue.init?(Any)` does not
/// handle Foundation collection types, so this converter checks for
/// `NSDictionary` / `NSArray` explicitly and recurses into nested structures.
///
/// Common Foundation reference types with a well-defined string form
/// (`Date`, `URL`, `UUID`, `Data`) are always mapped to that form, independent
/// of `stringifyUnknown`, so values bridged from Obj-C / .NET MAUI are never lost.
///
/// `stringifyUnknown` only controls what happens to values that have *no*
/// meaningful representation (e.g. an arbitrary object):
/// - `false` (default): drop the value, so it never appears as an attribute.
/// - `true`: fall back to `.string(String(describing:))`.
///
/// `null` (`NSNull`) is always dropped regardless of `stringifyUnknown`, mirroring
/// the `.null <-> NSNull` Foundation mapping — there is no OTel attribute form for
/// null, and emitting a `"<null>"` string would be misleading.
public enum AttributeConverter {

    private static let iso8601Formatter = ISO8601DateFormatter()

    /// Converts a `[String: Any]` dictionary into `[String: AttributeValue]`,
    /// omitting any entries whose value cannot be represented.
    public static func convert(_ source: [String: Any], stringifyUnknown: Bool = false) -> [String: AttributeValue] {
        var result: [String: AttributeValue] = [:]
        for (key, value) in source {
            if let converted = convertValue(value, stringifyUnknown: stringifyUnknown) {
                result[key] = converted
            }
        }
        return result
    }

    /// Converts a single value into an `AttributeValue`, or `nil` when it has no
    /// representable form (and `stringifyUnknown` is `false`).
    ///
    /// Resolution order:
    /// 1. `AttributeValue` / `[String: AttributeValue]` → used directly.
    /// 2. `NSNull`        → dropped (no OTel null form).
    /// 3. `NSDictionary`  → `.set(AttributeSet(labels: …))` (recursive)
    /// 4. `NSArray`       → `.array(AttributeArray(values: …))` (recursive)
    /// 5. `NSNumber`      → `.bool` / `.int` / `.double` based on `objCType`
    ///    (avoids Swift's special bridging that converts NSNumber(0/1) to Bool)
    /// 6. `String`        → `.string`
    /// 7. Swift `Bool`/`Int`/`Double` → guaranteed fallback for non-bridged scalars
    /// 8. `Date`/`URL`/`UUID`/`Data` → `.string` (well-defined form, always kept)
    /// 9. Unrepresentable → `.string(String(describing:))` when `stringifyUnknown`, else `nil`
    public static func convertValue(_ value: Any, stringifyUnknown: Bool = false) -> AttributeValue? {
        // Already an attribute value, or a whole attribute set: use directly.
        if let attributeValue = value as? AttributeValue { return attributeValue }
        if let labels = value as? [String: AttributeValue] {
            return .set(AttributeSet(labels: labels))
        }

        // Explicit null has no OTel attribute form; drop it (matching the
        // `.null <-> NSNull` Foundation mapping) rather than emitting "<null>".
        if value is NSNull { return nil }

        // Nested dictionary -> nested attribute set.
        if let nsDict = value as? NSDictionary {
            var labels: [String: AttributeValue] = [:]
            for (rawKey, nestedValue) in nsDict {
                if let key = rawKey as? String,
                   let converted = convertValue(nestedValue, stringifyUnknown: stringifyUnknown) {
                    labels[key] = converted
                }
            }
            return .set(AttributeSet(labels: labels))
        }

        // Array -> attribute array, dropping elements that can't be represented.
        if let nsArray = value as? NSArray {
            return .array(AttributeArray(values: nsArray.compactMap { convertValue($0, stringifyUnknown: stringifyUnknown) }))
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

        // Common Foundation reference types with a well-defined string form.
        // Handled explicitly (independent of `stringifyUnknown`) so values bridged
        // from Obj-C / .NET MAUI aren't silently dropped.
        if let date = value as? Date { return .string(iso8601Formatter.string(from: date)) }
        if let url = value as? URL { return .string(url.absoluteString) }
        if let uuid = value as? UUID { return .string(uuid.uuidString) }
        if let data = value as? Data { return .string(data.base64EncodedString()) }

        // Arbitrary objects with no meaningful form: stringify only when asked,
        // otherwise drop.
        return stringifyUnknown ? .string(String(describing: value)) : nil
    }
}
