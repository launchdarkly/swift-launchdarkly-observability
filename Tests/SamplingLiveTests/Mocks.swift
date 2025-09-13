import Foundation

@testable import OpenTelemetrySdk
import OpenTelemetryApi

func makeMockReadableLogRecord(
    body: AttributeValue? = nil,
    severity: Severity? = nil,
    attributes: [String: AttributeValue] = .init()
) -> ReadableLogRecord {
    .init(
        resource: .empty,
        instrumentationScopeInfo: .init(),
        timestamp: .now,
        severity: severity,
        body: body,
        attributes: attributes
    )
}

func makeMockSpanData(
    name: String,
    spanId: SpanId = .random(),
    parentSpanId: SpanId? = nil,
    events: [SpanData.Event] = [],
    attributes: [String: AttributeValue] = [:]
) -> SpanData {
    SpanData(
        traceId: .random(),
        spanId: spanId,
        parentSpanId: parentSpanId,
        name: name,
        kind: .client,
        startTime: .now,
        attributes: attributes,
        events: events,
        endTime: .now.addingTimeInterval(60 * 2)
    )
}

func makeMockSpanEvent(
    name: String,
    timestamp: Date = .now,
    attributes: [String: AttributeValue]? = nil
) -> SpanData.Event {
    SpanData.Event(
        name: name,
        timestamp: timestamp,
        attributes: attributes
    )
}
