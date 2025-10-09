import OSLog

import LaunchDarkly

import ApplicationServices
import ObservabilityServiceLive

public final class Observability: Plugin {
    private let options: Options
    static var associatedObjectKey: Int = 0
        
    public init(options: Options) {
        self.options = options
    }
    
    public func getMetadata() -> LaunchDarkly.PluginMetadata {
        return .init(name: options.serviceName)
    }
    
    public func register(client: LaunchDarkly.LDClient, metadata: LaunchDarkly.EnvironmentMetadata) {
        let mobileKey = metadata.credential
        
        var options = options
        var resourceAttributes = options.resourceAttributes
        var customHeaders = options.customHeaders
        
        resourceAttributes[SemanticConvention.launchdarklySdkVersion] = .string(String(format: "%@/%@", metadata.sdkMetadata.name, metadata.sdkMetadata.version))
        resourceAttributes[SemanticConvention.highlightProjectId] = .string(mobileKey)
     
        customHeaders[SemanticConvention.highlightProjectId] = mobileKey
        
        options.resourceAttributes = resourceAttributes
        options.customHeaders = customHeaders
        
        do {
            let observabilityService = try ObservabilityService.build(mobileKey: mobileKey, options: options)
            client.observabilityService = observabilityService
            LDObserve.shared.set(service: observabilityService)
        } catch {
            os_log("%{public}@", log: options.log, type: .error, "Observability Service initialization failed with error: \(error)")
        }
    }
    
    public func getHooks(metadata: EnvironmentMetadata) -> [any Hook] {
        [
            EvalTracingHook(withSpans: true, withValue: true, version: metadata.sdkMetadata.version)
        ]
    }
}

