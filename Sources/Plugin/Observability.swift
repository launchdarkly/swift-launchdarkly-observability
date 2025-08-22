import LaunchDarkly
import OpenTelemetryApi
import OpenTelemetrySdk
import ResourceExtension

import API
import Client
import LaunchDarklyObservability

public final class Observability: Plugin {
    public init() {}
    
    public func getMetadata() -> PluginMetadata {
        guard case let .string(serviceName) = DefaultResources().get().attributes["service.name"], !serviceName.isEmpty else {
            return .init(name: "'@launchdarkly/observability-ios'")
        }
        return .init(name: serviceName)
    }
    
    public func register(client: LDClient, metadata: EnvironmentMetadata) {
        let sdkKey = metadata.credential
        
        
        var resourceAttributes = DefaultResources().get().attributes
        resourceAttributes["launchdarkly.sdk.version"] = .string(String(format: "%@/%@", metadata.sdkMetadata.name, metadata.sdkMetadata.version))
        resourceAttributes["highlight.project_id"] = .string(sdkKey)
        
        let options = Options(resourceAttributes: resourceAttributes)
        let client = ObservabilityClient(sdkKey: sdkKey, resource: .init(attributes: resourceAttributes), options: options)
        
        LDObserve.shared.set(client: client)
    }
    
    public func getHooks(metadata: EnvironmentMetadata) -> [any Hook] {
        [
            EvalTracingHook(withSpans: true, withValue: true)
        ]
    }
}
