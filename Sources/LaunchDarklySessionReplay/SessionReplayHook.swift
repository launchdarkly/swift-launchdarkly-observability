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
        
        var attributes = [String: String]()
        attributes["key"] = seriesContext.context.fullyQualifiedKey()
        attributes["canonicalKey"] = seriesContext.context.fullyQualifiedKey()
        attributes["feature_flag.set.id"] = "548f6741c1efad40031b18ae"
        attributes["feature_flag.provider.name"] = "LaunchDarkly"
        attributes["telemetry.sdk.name"] = "iOSClient"
        attributes["user"] = "test"
        attributes["userIdentifier"] = "unknown"

        
        Task {
            do {
//                let identity = IdentityPayload(
//                    userIdentifier: "unknown",
//                    telemetrySdkName: "JSClient",
//                    telemetrySdkVersion: "3.8.1",
//                    featureFlagSetId: "548f6741c1efad40031b18ae",
//                    featureFlagProviderName: "LaunchDarkly",
//                    user: "test",
//                    key: "test",
//                    canonicalKey: "test"
//                )
                try await plugin.sessionReplayService?.sessionReplayExporter.scheduleIdentifySession(userObject: attributes)
            } catch {
                
            }
        }
        
        return seriesData
    }
}
