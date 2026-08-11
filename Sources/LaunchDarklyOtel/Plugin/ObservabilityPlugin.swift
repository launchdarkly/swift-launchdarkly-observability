import Foundation
import OSLog
@_exported import LaunchDarkly
import OpenTelemetrySdk
#if !LD_COCOAPODS
import SDKResourceExtension
#endif
#if !os(macOS)
import UIKit
#endif

/// Shared registration logic for the observability plugins: builds the OTel pipeline,
/// publishes it through ``LDObserve``, and wires the LaunchDarkly evaluation hooks.
///
/// Subclasses supply the automatic instrumentation. ``Otel`` supplies none, which is what
/// makes it safe to run beside another observability SDK; `LaunchDarklyObservability`
/// supplies the full set.
open class ObservabilityPlugin: Plugin {
    /// Uptime captured at the earliest SDK entry point. The plugin is constructed before any
    /// pipeline setup runs, so using this as the end of the startup window keeps
    /// `start.duration_ms` from being inflated by the SDK's own initialization.
    private let appStartEndUptime: TimeInterval = ProcessInfo.processInfo.systemUptime

    private let options: ObservabilityOptions
    private let instrumenting: ObservabilityInstrumenting?
    let observabilityHook = ObservabilityHook()
    public private(set) var observabilityService: ObservabilityService?
    public var distroAttributes: [String: String]

    /// - Parameters:
    ///   - options: Pipeline configuration. The `instrumentation` and `crashReporting`
    ///     sections have no effect unless an instrumentation provider is supplied.
    ///   - distroName: Value reported as `telemetry.distro.name`, identifying which
    ///     distribution produced the telemetry.
    ///   - instrumenting: Supplies the automatic instrumentation. `nil` installs nothing into
    ///     the host app, leaving only the manual recording API.
    public init(
        options: ObservabilityOptions,
        distroName: String,
        instrumenting: ObservabilityInstrumenting? = nil
    ) {
        self.options = options
        self.instrumenting = instrumenting
        self.distroAttributes = [
            SemanticConvention.telemetryDistroName: distroName,
            SemanticConvention.telemetryDistroVersion: sdkVersion
        ]
    }

    open func getMetadata() -> PluginMetadata {
        .init(name: options.serviceName)
    }

    open func register(client: LDClient, metadata: EnvironmentMetadata) {
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
            // Installed before the service is published so the setup values Session Replay
            // reads from the context are settled by the time its own plugin registers.
            if let instrumenting {
                service.install(instrumenting: instrumenting, appStartEndUptime: appStartEndUptime)
            }
            observabilityService = service
            LDObserve.shared.client = service
            LDObserve.shared.context = service.context

            observabilityHook.delegate = service.hookExporter

            if options.isEnabled {
                service.start()
            }
        } catch {
            os_log("%{public}@", log: options.log, type: .error, "Observability client initialization failed with error: \(error)")
        }
    }

    open func getHooks(metadata: EnvironmentMetadata) -> [any Hook] {
        return [observabilityHook]
    }
}

extension ObservabilityPlugin {
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
        return sessionAttributes
    }

    func add(metadata: EnvironmentMetadata, into resourceAttributes: inout [String: AttributeValue]) {
        resourceAttributes[SemanticConvention.serviceName] = .string(options.serviceName)
        resourceAttributes[SemanticConvention.serviceVersion] = .string(options.serviceVersion)
        resourceAttributes[SemanticConvention.launchdarklySdkVersion] = .string(String(format: "%@/%@", metadata.sdkMetadata.name, metadata.sdkMetadata.version))
        resourceAttributes[SemanticConvention.highlightProjectId] = .string(metadata.credential)
        resourceAttributes[SemanticConvention.telemetrySdkName] = .string("opentelemetry")
        for (key, value) in distroAttributes {
            resourceAttributes[key] = .string(value)
        }
    }
}
