/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// Adapter that converts `SpanData` instances into the OTLP/JSON wire-format
/// types declared in `OtlpJsonTraceModels.swift`.
public enum JsonSpanAdapter {
    public static func toJsonRequest(spanDataList: [SpanData]) -> OtlpJsonExportTraceServiceRequest {
        return OtlpJsonExportTraceServiceRequest(resourceSpans: toResourceSpans(spanDataList: spanDataList))
    }

    public static func toResourceSpans(spanDataList: [SpanData]) -> [OtlpJsonResourceSpans] {
        let grouped = groupByResourceAndScope(spanDataList: spanDataList)
        return grouped.map { resource, scopes in
            let scopeSpans: [OtlpJsonScopeSpans] = scopes.map { scopeInfo, spans in
                OtlpJsonScopeSpans(
                    scope: JsonCommonAdapter.toJsonInstrumentationScope(scopeInfo),
                    spans: spans,
                    schemaUrl: scopeInfo.schemaUrl
                )
            }
            return OtlpJsonResourceSpans(
                resource: JsonCommonAdapter.toJsonResource(resource),
                scopeSpans: scopeSpans
            )
        }
    }

    private static func groupByResourceAndScope(
        spanDataList: [SpanData]
    ) -> [Resource: [InstrumentationScopeInfo: [OtlpJsonSpan]]] {
        var result = [Resource: [InstrumentationScopeInfo: [OtlpJsonSpan]]]()
        for spanData in spanDataList {
            result[
                spanData.resource,
                default: [InstrumentationScopeInfo: [OtlpJsonSpan]]()
            ][
                spanData.instrumentationScope,
                default: [OtlpJsonSpan]()
            ].append(toJsonSpan(spanData))
        }
        return result
    }

    public static func toJsonSpan(_ spanData: SpanData) -> OtlpJsonSpan {
        let attributes = spanData.attributes.isEmpty
            ? nil
            : JsonCommonAdapter.toJsonAttributes(spanData.attributes)

        let events = spanData.events.isEmpty ? nil : spanData.events.map(toJsonSpanEvent)
        let links = spanData.links.isEmpty ? nil : spanData.links.map(toJsonSpanLink)

        let droppedAttributes = max(0, spanData.totalAttributeCount - spanData.attributes.count)
        let droppedEvents = max(0, spanData.totalRecordedEvents - spanData.events.count)
        let droppedLinks = max(0, spanData.totalRecordedLinks - spanData.links.count)

        return OtlpJsonSpan(
            traceId: spanData.traceId.hexString,
            spanId: spanData.spanId.hexString,
            traceState: encodeTraceState(spanData.traceState),
            parentSpanId: spanData.parentSpanId?.hexString,
            flags: UInt32(spanData.traceFlags.byte),
            name: spanData.name,
            kind: toJsonSpanKind(spanData.kind),
            startTimeUnixNano: OtlpJsonInt64(spanData.startTime.timeIntervalSince1970.toNanoseconds),
            endTimeUnixNano: OtlpJsonInt64(spanData.endTime.timeIntervalSince1970.toNanoseconds),
            attributes: attributes,
            droppedAttributesCount: droppedAttributes > 0 ? UInt32(droppedAttributes) : nil,
            events: events,
            droppedEventsCount: droppedEvents > 0 ? UInt32(droppedEvents) : nil,
            links: links,
            droppedLinksCount: droppedLinks > 0 ? UInt32(droppedLinks) : nil,
            status: toJsonStatus(spanData.status)
        )
    }

    public static func toJsonSpanEvent(_ event: SpanData.Event) -> OtlpJsonSpan.Event {
        OtlpJsonSpan.Event(
            timeUnixNano: OtlpJsonInt64(event.timestamp.timeIntervalSince1970.toNanoseconds),
            name: event.name,
            attributes: event.attributes.isEmpty
                ? nil
                : JsonCommonAdapter.toJsonAttributes(event.attributes)
        )
    }

    public static func toJsonSpanLink(_ link: SpanData.Link) -> OtlpJsonSpan.Link {
        OtlpJsonSpan.Link(
            traceId: link.context.traceId.hexString,
            spanId: link.context.spanId.hexString,
            traceState: encodeTraceState(link.context.traceState),
            attributes: link.attributes.isEmpty
                ? nil
                : JsonCommonAdapter.toJsonAttributes(link.attributes),
            flags: UInt32(link.context.traceFlags.byte)
        )
    }

    public static func toJsonSpanKind(_ kind: SpanKind) -> OtlpJsonSpanKind {
        switch kind {
        case .internal: return .internal
        case .server: return .server
        case .client: return .client
        case .producer: return .producer
        case .consumer: return .consumer
        }
    }

    /// `Status` rawValue numbers in the SDK do *not* match OTLP's enum
    /// numbering, so we map by case rather than rawValue.
    public static func toJsonStatus(_ status: Status) -> OtlpJsonStatus {
        switch status {
        case .ok:
            return OtlpJsonStatus(code: .ok)
        case .unset:
            return OtlpJsonStatus(code: .unset)
        case let .error(description):
            return OtlpJsonStatus(code: .error, message: description)
        }
    }

    /// Encodes `TraceState` in the W3C tracestate header format
    /// (`key1=value1,key2=value2`), per the OTLP spec.
    private static func encodeTraceState(_ traceState: TraceState) -> String? {
        let entries = traceState.entries
        guard !entries.isEmpty else { return nil }
        return entries.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
    }
}
