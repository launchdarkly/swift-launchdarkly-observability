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
        let sessionAttributes = plugin.observabilityContext?.sessionAttributes
        Task {
            let identifyPayload = await IdentifyItemPayload(options: options, sessionAttributes: sessionAttributes, ldContext: seriesContext.context, timestamp: Date().timeIntervalSince1970)
            await plugin.sessionReplayService?.scheduleIdentifySession(identifyPayload: identifyPayload)
        }
        
        return seriesData
    }
}
