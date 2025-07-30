import Foundation
import Shared
@preconcurrency import OpenTelemetrySdk
@preconcurrency import OpenTelemetryApi

@globalActor struct ObservabilityActor {
    actor Observability {}
    static let shared = Observability()
}

enum AttributeKey: String {
    case projectId = "highlight.project_id"
    case sessionId = "highlight.session_id"
    case xLaunchDarklyProjectHeader = "X-LaunchDarkly-Project"
}

public final class DefaultObservabilityClient {
    private let sdkKey: String
    let instrumentation: InstrumentationManager
    let session: Session
    
    public init(
        sdkKey: String,
        resource: Resource,
        configuration: Configuration
    ) {
        let sessionId = UUID().uuidString
        let session = DefaultSession(
            sessionInfo: .init(
                sessionId: sessionId,
                startTime: configuration.sessionTimeout
            )
        )

        let defaultAttributes = [
            ResourceAttributes.serviceName.rawValue: AttributeValue.string(configuration.serviceName),
            ResourceAttributes.serviceVersion.rawValue: AttributeValue.string(configuration.serviceVersion),
            ResourceAttributes.telemetrySdkName.rawValue: AttributeValue.string("swift-launchdarkly-observability"),
            ResourceAttributes.telemetrySdkLanguage.rawValue: AttributeValue.string("swift"),
            AttributeKey.projectId.rawValue : AttributeValue.string(sdkKey),
            AttributeKey.sessionId.rawValue: AttributeValue.string(sessionId),
            AttributeKey.xLaunchDarklyProjectHeader.rawValue: AttributeValue.string(sdkKey)
        ]
        
        let mergedResources = resource.merging(other: .init(attributes: defaultAttributes))
        
        let instrumentation = DefaultInstrumentation(
            configuration: configuration,
            resource: mergedResources,
            session: session
        )
        self.sdkKey = sdkKey
        self.instrumentation = instrumentation
        self.session = session
    }
    
    public func start() async {
        await instrumentation.start()
        await session.start()
    }
}

