import Foundation
import LaunchDarkly
import OpenTelemetryApi
import OpenTelemetrySdk
import ResourceExtension

import API
import Observability

public final class Observability: Plugin {
    private let options: Options
    public init(options: Options = Options(resourceAttributes: DefaultResources().get().attributes)) {
        self.options = options
    }
    public func getMetadata() -> PluginMetadata {
        guard !options.serviceName.isEmpty else {
            return .init(name: "'@launchdarkly/observability-ios'")
        }
        return .init(name: options.serviceName)
    }
    
    public func register(client: LDClient, metadata: EnvironmentMetadata) {
        let sdkKey = metadata.credential
        
        
        var resourceAttributes = DefaultResources().get().attributes
        resourceAttributes["launchdarkly.sdk.version"] = .string(String(format: "%@/%@", metadata.sdkMetadata.name, metadata.sdkMetadata.version))
        resourceAttributes["highlight.project_id"] = .string(sdkKey)
        
        let options = Options(
            serviceName: options.serviceName,
            serviceVersion: options.serviceVersion,
            otlpEndpoint: options.otlpEndpoint,
            backendUrl: options.backendUrl,
            resourceAttributes: options.resourceAttributes.merging(resourceAttributes) { (old, _) in old },
            customHeaders: options.customHeaders,
            sessionBackgroundTimeout: options.sessionBackgroundTimeout,
            isDebug: options.isDebug,
            disableErrorTracking: options.disableErrorTracking,
            disableLogs: options.disableLogs,
            disableTraces: options.disableTraces,
            disableMetrics: options.disableMetrics,
            loggerName: options.loggerName
        )
        let client = ObservabilityClient(
            context: .init(
                sdkKey: sdkKey,
                resource: .init(attributes: resourceAttributes),
                options: options,
                logger: .init(name: options.loggerName)
            )
        )
        
        LDObserve.shared.set(client: client)
    }
    
    public func getHooks(metadata: EnvironmentMetadata) -> [any Hook] {
        [
            EvalTracingHook(withSpans: true, withValue: true, version: metadata.sdkMetadata.version)
        ]
    }
}
