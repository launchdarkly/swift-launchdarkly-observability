import Foundation
import LaunchDarkly
import LaunchDarklyObservability
#if LD_COCOAPODS
    import LaunchDarklyObservability
#else
    import Common
#endif

/// Hook protocol adapter for native Swift SDK usage.
/// Extracts data from SDK types and delegates to SessionReplayHookExporter.
final class SessionReplayHook: Hook {
    weak var delegate: SessionReplayServicing?

    init() {
    }

    public func metadata() -> Metadata {
        return Metadata(name: "SessionReplay")
    }

    public func afterIdentify(seriesContext: IdentifySeriesContext, seriesData: IdentifySeriesData, result: IdentifyResult) -> IdentifySeriesData {
        guard case .complete = result, let delegate else {
            return seriesData
        }

        var keys = [String: String]()
        for (k, v) in seriesContext.context.contextKeys() { keys[k] = v }

        delegate.afterIdentify(
            contextKeys: keys,
            canonicalKey: seriesContext.context.fullyQualifiedKey(),
            completed: true
        )
        return seriesData
    }

    public func afterTrack(seriesContext: TrackSeriesContext) {
        guard let delegate else { return }

        var attributes = [String: AttributeValue]()
        if case let .object(data) = seriesContext.data {
            for (k, v) in data {
                if let attr = Self.attributeValue(from: v) {
                    attributes[k] = attr
                }
            }
        }

        delegate.afterTrack(
            name: seriesContext.key,
            value: seriesContext.metricValue,
            attributes: attributes
        )
    }

    private static func attributeValue(from value: LDValue) -> AttributeValue? {
        switch value {
        case .bool(let b): return .bool(b)
        case .number(let n): return .double(n)
        case .string(let s): return .string(s)
        case .null, .array, .object: return nil
        }
    }
}
