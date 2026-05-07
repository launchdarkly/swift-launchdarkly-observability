import Foundation
import Testing
import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import JSONExporters

struct JsonSpanAdapterTests {
    @Test("Encodes spans as OTLP/JSON with proper field naming")
    func encodesSpan() throws {
        let traceIdHex = "0102030405060708090a0b0c0d0e0f10"
        let spanIdHex = "1112131415161718"
        let parentHex = "2122232425262728"
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_000_001)

        let spanData = SpanData(
            traceId: TraceId(fromHexString: traceIdHex),
            spanId: SpanId(fromHexString: spanIdHex),
            traceFlags: TraceFlags().settingIsSampled(true),
            traceState: TraceState(),
            parentSpanId: SpanId(fromHexString: parentHex),
            resource: Resource(attributes: ["service.name": .string("test-service")]),
            instrumentationScope: InstrumentationScopeInfo(name: "test-scope", version: "1.2.3"),
            name: "GET /users",
            kind: .client,
            startTime: start,
            attributes: ["http.status_code": .int(200)],
            events: [],
            links: [],
            status: .ok,
            endTime: end,
            hasRemoteParent: false,
            hasEnded: true,
            totalRecordedEvents: 0,
            totalRecordedLinks: 0,
            totalAttributeCount: 1
        )

        let request = JsonSpanAdapter.toJsonRequest(spanDataList: [spanData])
        let json = try JsonTestHelpers.encodeJson(request)

        let resourceSpans = try JsonTestHelpers.cast(json["resourceSpans"], as: [Any].self)
        let resourceSpan = try JsonTestHelpers.cast(resourceSpans[0], as: [String: Any].self)

        let resource = try JsonTestHelpers.cast(resourceSpan["resource"], as: [String: Any].self)
        let resourceAttrs = try JsonTestHelpers.cast(resource["attributes"], as: [Any].self)
        let firstAttr = try JsonTestHelpers.cast(resourceAttrs[0], as: [String: Any].self)
        #expect(firstAttr["key"] as? String == "service.name")

        let scopeSpans = try JsonTestHelpers.cast(resourceSpan["scopeSpans"], as: [Any].self)
        let scopeSpan = try JsonTestHelpers.cast(scopeSpans[0], as: [String: Any].self)
        let scope = try JsonTestHelpers.cast(scopeSpan["scope"], as: [String: Any].self)
        #expect(scope["name"] as? String == "test-scope")
        #expect(scope["version"] as? String == "1.2.3")

        let spans = try JsonTestHelpers.cast(scopeSpan["spans"], as: [Any].self)
        let span = try JsonTestHelpers.cast(spans[0], as: [String: Any].self)

        #expect(span["traceId"] as? String == traceIdHex)
        #expect(span["spanId"] as? String == spanIdHex)
        #expect(span["parentSpanId"] as? String == parentHex)
        #expect(span["name"] as? String == "GET /users")
        // Span kind uses the canonical proto-JSON enum string form.
        #expect(span["kind"] as? String == "SPAN_KIND_CLIENT")
        // 64-bit ints serialize as decimal strings.
        #expect(span["startTimeUnixNano"] as? String == "1700000000000000000")
        #expect(span["endTimeUnixNano"] as? String == "1700000001000000000")
        #expect(span["flags"] as? Int == 1)

        let status = try JsonTestHelpers.cast(span["status"], as: [String: Any].self)
        #expect(status["code"] as? String == "STATUS_CODE_OK")
        #expect(status["message"] == nil)

        let attributes = try JsonTestHelpers.cast(span["attributes"], as: [Any].self)
        let attr = try JsonTestHelpers.cast(attributes[0], as: [String: Any].self)
        let attrValue = try JsonTestHelpers.cast(attr["value"], as: [String: Any].self)
        #expect(attrValue["intValue"] as? String == "200")
    }

    @Test("Encodes events, links and error status")
    func encodesEventsLinksAndErrorStatus() throws {
        let linkedTraceHex = "aabbccddeeff00112233445566778899"
        let linkedSpanHex = "9988776655443322"

        let linkedContext = SpanContext.create(
            traceId: TraceId(fromHexString: linkedTraceHex),
            spanId: SpanId(fromHexString: linkedSpanHex),
            traceFlags: TraceFlags(),
            traceState: TraceState()
        )

        let event = SpanData.Event(
            name: "exception",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            attributes: ["exception.type": .string("OOM")]
        )

        let link = SpanData.Link(
            context: linkedContext,
            attributes: ["link.kind": .string("follows-from")]
        )

        let spanData = SpanData(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            parentSpanId: nil,
            name: "boom",
            kind: .internal,
            startTime: Date(),
            events: [event],
            links: [link],
            status: .error(description: "out of memory"),
            endTime: Date()
        )

        let request = JsonSpanAdapter.toJsonRequest(spanDataList: [spanData])
        let json = try JsonTestHelpers.encodeJson(request)
        let span = try drillToSpan(json)

        // Status with message.
        let status = try JsonTestHelpers.cast(span["status"], as: [String: Any].self)
        #expect(status["code"] as? String == "STATUS_CODE_ERROR")
        #expect(status["message"] as? String == "out of memory")

        // Event.
        let events = try JsonTestHelpers.cast(span["events"], as: [Any].self)
        let firstEvent = try JsonTestHelpers.cast(events[0], as: [String: Any].self)
        #expect(firstEvent["name"] as? String == "exception")
        #expect(firstEvent["timeUnixNano"] as? String == "1700000000000000000")

        // Link.
        let links = try JsonTestHelpers.cast(span["links"], as: [Any].self)
        let firstLink = try JsonTestHelpers.cast(links[0], as: [String: Any].self)
        #expect(firstLink["traceId"] as? String == linkedTraceHex)
        #expect(firstLink["spanId"] as? String == linkedSpanHex)
    }

    @Test("Maps SpanKind cases to the canonical proto-JSON enum strings")
    func mapsAllSpanKinds() {
        let pairs: [(SpanKind, String)] = [
            (.internal, "SPAN_KIND_INTERNAL"),
            (.server, "SPAN_KIND_SERVER"),
            (.client, "SPAN_KIND_CLIENT"),
            (.producer, "SPAN_KIND_PRODUCER"),
            (.consumer, "SPAN_KIND_CONSUMER"),
        ]
        for (kind, expected) in pairs {
            #expect(JsonSpanAdapter.toJsonSpanKind(kind).rawValue == expected)
        }
    }

    // MARK: - Helpers

    private func drillToSpan(_ json: [String: Any]) throws -> [String: Any] {
        let resourceSpans = try JsonTestHelpers.cast(json["resourceSpans"], as: [Any].self)
        let resourceSpan = try JsonTestHelpers.cast(resourceSpans[0], as: [String: Any].self)
        let scopeSpans = try JsonTestHelpers.cast(resourceSpan["scopeSpans"], as: [Any].self)
        let scopeSpan = try JsonTestHelpers.cast(scopeSpans[0], as: [String: Any].self)
        let spans = try JsonTestHelpers.cast(scopeSpan["spans"], as: [Any].self)
        return try JsonTestHelpers.cast(spans[0], as: [String: Any].self)
    }
}
