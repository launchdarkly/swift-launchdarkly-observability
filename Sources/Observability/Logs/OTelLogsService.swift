import Foundation
import OpenTelemetrySdk
import OpenTelemetryApi

final class OTelLogsService {
    private let sessionService: SessionService
    private let options: Options
    private let eventQueue: EventQueue
    private let resource: Resource
    private let instrumentationScope: InstrumentationScopeInfo
    private let sampler: ExportSampler
    
    init(
        sessionService: SessionService,
        options: Options,
        sampler: ExportSampler,
        eventQueue: EventQueue
    ) {
        self.sampler = sampler
        self.resource = Resource(attributes: options.resourceAttributes.mapValues { $0.toOTel() })
        self.sessionService = sessionService
        self.options = options
        self.eventQueue = eventQueue
        self.instrumentationScope = .init(name: options.serviceName)
    }
    
    // MARK: - API
    
    func recordLog(
        message: String,
        severity: Observability.Severity,
        attributes: [String: Observability.AttributeValue]
    ) {
        var attributes = attributes
        let sessionId = sessionService.sessionInfo().id
        if !sessionId.isEmpty {
            attributes[SemanticConvention.highlightSessionId] = .string(sessionId)
        }
        
        let logBuilder = ObservabilityLogRecordBuilder(queue: eventQueue,
                                                       sampler: sampler,
                                                       resource: resource,
                                                       clock: MillisClock(),
                                                       instrumentationScope: instrumentationScope,
                                                       includeSpanContext: true)

     
        
        logBuilder.setBody(.string(message))
            .setTimestamp(Date())
            .setSeverity(severity.toOtel())
            .setAttributes(attributes.mapValues { $0.toOTel() })
            .emit()
    }
    
    func flush() async -> Bool {
        // TODO:
        return true
    }
}
