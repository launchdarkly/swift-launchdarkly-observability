import OSLog
@_exported import LaunchDarkly
@_exported import Observability

public final class Observability: Plugin {
    private let options: Options
    
    public init(options: Options) {
        self.options = options
    }
    
    public func getMetadata() -> PluginMetadata {
        .init(name: options.serviceName)
    }
    
    public func register(client: LDClient, metadata: EnvironmentMetadata) {
        let mobileKey = metadata.credential
        
        var options = options
        var resourceAttributes = options.resourceAttributes
        var customHeaders = options.customHeaders
        
        resourceAttributes[SemanticConvention.launchdarklySdkVersion] = .string(String(format: "%@/%@", metadata.sdkMetadata.name, metadata.sdkMetadata.version))
        resourceAttributes[SemanticConvention.highlightProjectId] = .string(mobileKey)
        resourceAttributes[SemanticConvention.serviceName] = .string(options.serviceName)
        resourceAttributes[SemanticConvention.serviceVersion] = .string(options.serviceVersion)
        
        customHeaders[SemanticConvention.highlightProjectId] = mobileKey
        
        options.resourceAttributes = resourceAttributes
        options.customHeaders = customHeaders
        
        do {
            let service = try ObservabilityClientFactory.instantiate(
                withOptions: options,
                mobileKey: mobileKey
            )
            client.observabilityService = service
            LDObserve.shared.client = service
        } catch {
            os_log("%{public}@", log: options.log, type: .error, "Observability client initialization failed with error: \(error)")
        }
    }
    
    public func getHooks(metadata: EnvironmentMetadata) -> [any Hook] {
        [EvalTracingHook(withSpans: true, withValue: true, version: options.serviceVersion, options: options)]
    }
}
