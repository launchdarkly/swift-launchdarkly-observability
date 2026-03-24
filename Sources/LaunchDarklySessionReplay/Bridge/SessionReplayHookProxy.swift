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
}
