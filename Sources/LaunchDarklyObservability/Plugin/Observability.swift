import OSLog

import LaunchDarkly

import ApplicationServices
import ObservabilityServiceLive

public final class Observability: Plugin {
    private let options: Options
    
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
        
        resourceAttributes["launchdarkly.sdk.version"] = .string(String(format: "%@/%@", metadata.sdkMetadata.name, metadata.sdkMetadata.version))
        resourceAttributes["highlight.project_id"] = .string(mobileKey)
     
        if !customHeaders.contains(where: { $0.0 == "highlight.project_id" }) {
            customHeaders.append(("highlight.project_id", mobileKey))
        }
        
        options.resourceAttributes = resourceAttributes
        options.customHeaders = customHeaders
        
        do {
            LDObserve.shared.set(service: try ObservabilityService.build(mobileKey: mobileKey, options: options))
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

/*
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
*/
