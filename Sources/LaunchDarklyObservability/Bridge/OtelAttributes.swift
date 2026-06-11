import Foundation
import OpenTelemetryApi

extension Dictionary where Key == String, Value == Any {
    /// Converts a `track`/log/span `properties` payload into OTel attributes.
    ///
    /// Structure is preserved (scalars, nested dictionaries, arrays, and
    /// pre-built `AttributeValue`s). Values with no attribute form (e.g. a `Date`
    /// or `null`) are dropped rather than stringified. Thin convenience wrapper
    /// over ``AttributeConverter/convert(_:stringifyUnknown:)``.
    func toOtelAttributes() -> [String: AttributeValue] {
        AttributeConverter.convert(self, stringifyUnknown: false)
    }
}
