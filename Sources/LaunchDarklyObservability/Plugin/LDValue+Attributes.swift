import LaunchDarkly
import OpenTelemetryApi
#if !LD_COCOAPODS
import Common
#endif

extension LDValue {
    /// Converts an object payload (e.g. a `track` event's `data`) into a flat
    /// attribute map.
    ///
    /// Reuses `AttributeConverter` for the value mapping by first bridging to
    /// Foundation, so scalar/array/object handling stays in one place. Only
    /// object payloads have key/value members; scalar and array payloads map to
    /// an empty dictionary.
    package func toAttributes() -> [String: AttributeValue] {
        guard case .object = self else { return [:] }
        return AttributeConverter.convert((toFoundation() as? [String: Any]) ?? [:])
    }
}
