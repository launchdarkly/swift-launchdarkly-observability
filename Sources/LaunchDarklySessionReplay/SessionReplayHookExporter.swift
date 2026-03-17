import Foundation
import LaunchDarklyObservability
#if LD_COCOAPODS
    import LaunchDarklyObservability
#else
    import Common
#endif

/// Pure session-replay logic for identify events.
///
/// Takes only simple Swift types — no Hook protocol, no @objc.
/// Both SessionReplayHook (native Swift) and SessionReplayHookProxy (C# bridge)
/// delegate here so the replay logic is written exactly once.
final class SessionReplayHookExporter {
    weak var plugin: SessionReplay?

    init(plugin: SessionReplay) {
        self.plugin = plugin
    }

    func afterIdentify(contextKeys: [String: String], canonicalKey: String, completed: Bool) {
        guard completed else { return }
        guard let options = plugin?.observabilityContext?.options else { return }

        let sessionAttributes = plugin?.observabilityContext?.sessionAttributes
        Task {
            let identifyPayload = IdentifyItemPayload(
                options: options,
                sessionAttributes: sessionAttributes,
                contextKeys: contextKeys,
                canonicalKey: canonicalKey,
                timestamp: Date().timeIntervalSince1970
            )
            await plugin?.sessionReplayService?.scheduleIdentifySession(identifyPayload: identifyPayload)
        }
    }
}
