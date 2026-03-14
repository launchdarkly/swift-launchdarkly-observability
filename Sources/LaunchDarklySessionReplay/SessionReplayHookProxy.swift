import Foundation
import LaunchDarklyObservability

/// @objc adapter for the C# / MAUI bridge.
/// Converts Foundation types (NSObject, NSDictionary) to Swift types
/// and delegates to SessionReplay so the replay identify logic is accessible
/// from the Xamarin.iOS binding.
@objc(SessionReplayHookProxy)
public final class SessionReplayHookProxy: NSObject {
    private let plugin: SessionReplay

    init(plugin: SessionReplay) {
        self.plugin = plugin
        super.init()
    }

    @objc(afterIdentifyWithContextKeys:canonicalKey:completed:)
    public func afterIdentify(contextKeys: NSDictionary, canonicalKey: String, completed: Bool) {
        guard completed else { return }
        guard let options = plugin.observabilityContext?.options else { return }

        var keys = [String: String]()
        for (k, v) in contextKeys {
            if let key = k as? String, let val = v as? String { keys[key] = val }
        }

        let sessionAttributes = plugin.observabilityContext?.sessionAttributes
        Task {
            let identifyPayload = IdentifyItemPayload(
                options: options,
                sessionAttributes: sessionAttributes,
                contextKeys: keys,
                canonicalKey: canonicalKey,
                timestamp: Date().timeIntervalSince1970
            )
            await plugin.sessionReplayService?.scheduleIdentifySession(identifyPayload: identifyPayload)
        }
    }
}
