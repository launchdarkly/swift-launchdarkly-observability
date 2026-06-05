import Foundation
import LaunchDarklyObservability
#if LD_COCOAPODS
    import LaunchDarklyObservability
#else
    import Common
#endif

/// @objc adapter for the C# / MAUI bridge.
/// Converts Foundation types to Swift types
/// and delegates to SessionReplayHookExporter.
@objc(SessionReplayHookProxy)
public final class SessionReplayHookProxy: NSObject {
    private let sessionReplayService: SessionReplayServicing

    init(sessionReplayService: SessionReplayServicing) {
        self.sessionReplayService = sessionReplayService
        super.init()
    }

    @objc(afterIdentifyWithContextKeys:canonicalKey:completed:)
    public func afterIdentify(contextKeys: NSDictionary, canonicalKey: String, completed: Bool) {
        var keys = [String: String]()
        for (k, v) in contextKeys {
            if let key = k as? String, let val = v as? String { keys[key] = val }
        }
        sessionReplayService.afterIdentify(contextKeys: keys, canonicalKey: canonicalKey, completed: completed)
    }

    @objc(afterTrackWithName:value:attributes:)
    public func afterTrack(name: String, value: NSNumber?, attributes: NSDictionary) {
        var attrs = [String: AttributeValue]()
        for (k, v) in attributes {
            guard let key = k as? String else { continue }
            if let s = v as? String {
                attrs[key] = .string(s)
            } else if let n = v as? NSNumber {
                attrs[key] = .double(n.doubleValue)
            }
        }
        sessionReplayService.afterTrack(name: name, value: value?.doubleValue, attributes: attrs)
    }
}
