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
}
