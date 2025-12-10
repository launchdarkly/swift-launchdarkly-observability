import Foundation
import LaunchDarkly
import LaunchDarklyObservability
#if !LD_COCOAPODS
    import Common
#endif

final class SessionReplayHook: Hook {
    private let plugin: SessionReplay
    
    init(plugin: SessionReplay) {
        self.plugin = plugin
    }
    
    public func metadata() -> Metadata {
        return Metadata(name: "SessionReplay")
    }
    
    public func afterIdentify(seriesContext: IdentifySeriesContext, seriesData: IdentifySeriesData, result: IdentifyResult) -> IdentifySeriesData {
        guard case .complete = result else {
            return seriesData
        }
        
        guard let options = plugin.observabilityContext?.options else {
            return seriesData
        }
        
        let context = seriesContext.context
        var attributes = options.resourceAttributes.mapValues(String.init(describing:))
        for (k, v) in context.contextKeys() {
            attributes[k] = v
        }
        
        let canonicalKey = context.fullyQualifiedKey()
        attributes["key"] = options.contextFriendlyName ?? canonicalKey
        attributes["canonicalKey"] = canonicalKey
        
        Task {
            await plugin.sessionReplayService?.scheduleIdentifySession(userObject: attributes)
        }
        
        return seriesData
    }
}
