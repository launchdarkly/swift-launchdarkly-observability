import OSLog
@_exported import LaunchDarkly
import OpenTelemetrySdk
import SDKResourceExtension
#if !os(macOS)
import UIKit
#endif

public final class Observability: Plugin {
    private let options: Options
    var observabilityService: InternalObserve?
    
    public init(options: Options) {
        self.options = options
        if options.crashReporting.source == .KSCrash {
            /// Very first thing to do, if crash reporting is enabled and it is KSCrash
            /// Then, try to install before doing anything else
            do {
                try KSCrashReportService.install()
            } catch {
                os_log("%{public}@", log: options.log, type: .error, "Observability crash reporting service initialization failed with error: \(error)")
            }
        }
    }
    
    public func getMetadata() -> PluginMetadata {
        .init(name: options.serviceName)
    }
    
    public func register(client: LDClient, metadata: EnvironmentMetadata) {
        let mobileKey = metadata.credential
        
        var options = options
        var resourceAttributes = options.resourceAttributes
        var customHeaders = options.customHeaders
        
        add(metadata: metadata, into: &resourceAttributes)
        let sessionAttributes = makeSessionAttributes()

        customHeaders[SemanticConvention.highlightProjectId] = mobileKey
        
        options.resourceAttributes = resourceAttributes
        options.customHeaders = customHeaders
        
        do {
            guard LDObserve.shared.client === NoOpObservabilityService.shared else {
                throw PluginError.observabilityInstanceAlreadyExist
            }
            let service = try ObservabilityService(
                options: options,
                mobileKey: mobileKey,
                sessionAttributes: sessionAttributes
            )
            observabilityService = service
            LDObserve.shared.client = service
            LDObserve.shared.context = service.context
            LDObserve.shared.plugin = self
            
            if options.isEnabled {
                service.start()
            }
        } catch {
            os_log("%{public}@", log: options.log, type: .error, "Observability client initialization failed with error: \(error)")
        }
    }
    
    public func getHooks(metadata: EnvironmentMetadata) -> [any Hook] {
        let exporter = ObservabilityHookExporter(
            plugin: self,
            withSpans: true,
            withValue: true,
            options: options
        )
        LDObserve.shared.hookProxy = ObservabilityHookProxy(exporter: exporter)
        return [ObservabilityHook(exporter: exporter)]
    }
}

extension Observability {
    func makeSessionAttributes() -> [String: AttributeValue] {
        var sessionAttributes = [String: AttributeValue]()
        // Device attributes
        let deviceDataSource = DeviceDataSource()
        #if !os(macOS)
        sessionAttributes[SemanticConvention.deviceModelName] = .string(UIDevice.current.model)
        #endif
        if let deviceModelIdentifier = deviceDataSource.model {
            sessionAttributes[SemanticConvention.deviceModelIdentifier] = .string(deviceModelIdentifier)
        }
        sessionAttributes[SemanticConvention.deviceManufacturer] = .string("Apple")

        // OS attributes
        let osDataSource = OperatingSystemDataSource()
        sessionAttributes[SemanticConvention.osName] = .string(osDataSource.name)
        sessionAttributes[SemanticConvention.osType] = .string(osDataSource.type)
        sessionAttributes[SemanticConvention.osVersion] = .string(osDataSource.version)
        sessionAttributes[SemanticConvention.osDescription] = .string(osDataSource.description)
        
        return sessionAttributes
    }
    
    func add(metadata: EnvironmentMetadata, into resourceAttributes: inout [String: AttributeValue]) {
        resourceAttributes[SemanticConvention.launchdarklySdkVersion] = .string(String(format: "%@/%@", metadata.sdkMetadata.name, metadata.sdkMetadata.version))
        resourceAttributes[SemanticConvention.highlightProjectId] = .string(metadata.credential)
        resourceAttributes[SemanticConvention.serviceName] = .string(options.serviceName)
        resourceAttributes[SemanticConvention.serviceVersion] = .string(options.serviceVersion)
        resourceAttributes[SemanticConvention.telemetryDistroName] = .string("swift-launchdarkly-observability")
        resourceAttributes[SemanticConvention.telemetryDistroVersion] = .string(sdkVersion)
    }
}
