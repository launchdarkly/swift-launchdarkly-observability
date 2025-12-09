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
    
    public func afterIdentify(seriesContext: IdentifySeriesContext, seriesData: EvaluationSeriesData, result: IdentifyResult) -> EvaluationSeriesData {
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
            do {
                try await plugin.sessionReplayService?.scheduleIdentifySession(userObject: attributes)
            } catch {
                
            }
        }
        
        return seriesData
    }
}
