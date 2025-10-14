import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public class ObservabilityLogRecordBuilder: EventBuilder {
    private var limits: LogLimits
    private var instrumentationScope: InstrumentationScopeInfo
    private var includeSpanContext: Bool
    private var timestamp: Date?
    private var observedTimestamp: Date?
    private var body: OpenTelemetryApi.AttributeValue?
    private var severity: OpenTelemetryApi.Severity?
    private var attributes: AttributesDictionary
    private var spanContext: SpanContext?
    private var resource: Resource
    private var clock: Clock
    private var queue: EventQueuing
    private let sampler: ExportSampler
    
    public init(queue: EventQueuing,
                sampler: ExportSampler,
                resource: Resource,
                clock: Clock,
                instrumentationScope: InstrumentationScopeInfo,
                includeSpanContext: Bool) {
        self.queue = queue
        self.sampler = sampler
        self.resource = resource
        self.clock = clock
        let logLimits = LogLimits()
        self.limits = logLimits
        self.includeSpanContext = includeSpanContext
        self.instrumentationScope = instrumentationScope
        self.attributes = AttributesDictionary(capacity: logLimits.maxAttributeCount,
                                               valueLengthLimit: logLimits.maxAttributeLength)
    }
    
    public func setTimestamp(_ timestamp: Date) -> Self {
        self.timestamp = timestamp
        return self
    }
    
    public func setObservedTimestamp(_ observed: Date) -> Self {
        observedTimestamp = observed
        return self
    }
    
    public func setSpanContext(_ context: OpenTelemetryApi.SpanContext) -> Self {
        spanContext = context
        return self
    }
    
    public func setSeverity(_ severity: OpenTelemetryApi.Severity) -> Self {
        self.severity = severity
        return self
    }
    
    public func setBody(_ body: OpenTelemetryApi.AttributeValue) -> Self {
        self.body = body
        return self
    }
    
    public func setAttributes(_ attributes: [String: OpenTelemetryApi.AttributeValue]) -> Self {
        self.attributes.updateValues(attributes: attributes)
        return self
    }
    
    public func setData(_ attributes: [String: OpenTelemetryApi.AttributeValue]) -> Self {
        self.attributes["event.data"] = OpenTelemetryApi.AttributeValue(AttributeSet(labels: attributes))
        return self
    }
    
    public func emit() {
        if spanContext == nil, includeSpanContext {
            spanContext = OpenTelemetry.instance.contextProvider.activeSpan?.context
        }
    
        Task {
            let attrs = attributes.reduce(into: [String: OpenTelemetryApi.AttributeValue]()) { result, element in
                result[element.0] = element.1
            }
        
            let log = ReadableLogRecord(resource: resource,
                                        instrumentationScopeInfo: instrumentationScope,
                                        timestamp: timestamp ?? clock.now,
                                        observedTimestamp: observedTimestamp,
                                        spanContext: spanContext,
                                        severity: severity,
                                        body: body,
                                        attributes: attrs)
            
            guard let sampledLog = sampler.sampledLog(log) else {
                return
            }
            
            await queue.send(EventQueueItem(payload: LogItem(log: sampledLog)))
        }
    }
}
