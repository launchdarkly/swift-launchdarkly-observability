import Foundation
import Testing
import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import OpenTelemetryProtocolExporterCommon

struct JsonLogRecordAdapterTests {
    @Test("Encodes log records as OTLP/JSON with proper field naming")
    func encodesLogRecord() throws {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let observed = Date(timeIntervalSince1970: 1_700_000_001)

        let record = ReadableLogRecord(
            resource: Resource(attributes: ["service.name": .string("test-service")]),
            instrumentationScopeInfo: InstrumentationScopeInfo(name: "test-scope", version: "1.2.3"),
            timestamp: timestamp,
            observedTimestamp: observed,
            severity: .info,
            body: .string("hello"),
            attributes: ["http.status_code": .int(200)]
        )

        let request = JsonLogRecordAdapter.toJsonRequest(logRecordList: [record])
        let json = try encodeJson(request)

        // Top-level structure
        let resourceLogs = try cast(json["resourceLogs"], as: [Any].self)
        #expect(resourceLogs.count == 1)
        let resourceLog = try cast(resourceLogs[0], as: [String: Any].self)

        // Resource attributes
        let resource = try cast(resourceLog["resource"], as: [String: Any].self)
        let resourceAttrs = try cast(resource["attributes"], as: [Any].self)
        let firstAttr = try cast(resourceAttrs[0], as: [String: Any].self)
        #expect(firstAttr["key"] as? String == "service.name")
        let firstValue = try cast(firstAttr["value"], as: [String: Any].self)
        #expect(firstValue["stringValue"] as? String == "test-service")

        // Scope logs
        let scopeLogs = try cast(resourceLog["scopeLogs"], as: [Any].self)
        let scopeLog = try cast(scopeLogs[0], as: [String: Any].self)
        let scope = try cast(scopeLog["scope"], as: [String: Any].self)
        #expect(scope["name"] as? String == "test-scope")
        #expect(scope["version"] as? String == "1.2.3")

        // Log record
        let logRecords = try cast(scopeLog["logRecords"], as: [Any].self)
        let logRecord = try cast(logRecords[0], as: [String: Any].self)

        // 64-bit ints must be JSON strings.
        #expect(logRecord["timeUnixNano"] as? String == "1700000000000000000")
        #expect(logRecord["observedTimeUnixNano"] as? String == "1700000001000000000")

        // Severity
        #expect(logRecord["severityNumber"] as? Int == Int(Severity.info.rawValue))
        #expect(logRecord["severityText"] as? String == "INFO")

        // Body uses the AnyValue oneof representation.
        let body = try cast(logRecord["body"], as: [String: Any].self)
        #expect(body["stringValue"] as? String == "hello")

        // Attribute int values are encoded as strings inside `intValue`.
        let logAttrs = try cast(logRecord["attributes"], as: [Any].self)
        let logAttr = try cast(logAttrs[0], as: [String: Any].self)
        #expect(logAttr["key"] as? String == "http.status_code")
        let logAttrValue = try cast(logAttr["value"], as: [String: Any].self)
        #expect(logAttrValue["intValue"] as? String == "200")
    }

    @Test("Encodes traceId and spanId as lowercase hex strings")
    func encodesIdsAsHex() throws {
        let traceIdHex = "0102030405060708090a0b0c0d0e0f10"
        let spanIdHex = "1112131415161718"

        let context = SpanContext.create(
            traceId: TraceId(fromHexString: traceIdHex),
            spanId: SpanId(fromHexString: spanIdHex),
            traceFlags: TraceFlags().settingIsSampled(true),
            traceState: TraceState()
        )

        let record = ReadableLogRecord(
            resource: .empty,
            instrumentationScopeInfo: InstrumentationScopeInfo(name: "scope"),
            timestamp: Date(),
            spanContext: context,
            attributes: [:]
        )

        let request = JsonLogRecordAdapter.toJsonRequest(logRecordList: [record])
        let json = try encodeJson(request)

        let logRecord = try drillToLogRecord(json)
        #expect(logRecord["traceId"] as? String == traceIdHex)
        #expect(logRecord["spanId"] as? String == spanIdHex)
        #expect(logRecord["flags"] as? Int == 1)
    }

    @Test("Encodes nested array and kvlist attributes")
    func encodesComplexAttributes() throws {
        let record = ReadableLogRecord(
            resource: .empty,
            instrumentationScopeInfo: InstrumentationScopeInfo(name: "scope"),
            timestamp: Date(),
            attributes: [
                "tags": .array(AttributeArray(values: [.string("a"), .string("b")])),
                "labels": .set(AttributeSet(labels: ["env": .string("prod")]))
            ]
        )

        let request = JsonLogRecordAdapter.toJsonRequest(logRecordList: [record])
        let json = try encodeJson(request)

        let logRecord = try drillToLogRecord(json)
        let attributes = try cast(logRecord["attributes"], as: [Any].self)
        var byKey: [String: [String: Any]] = [:]
        for raw in attributes {
            let attr = try cast(raw, as: [String: Any].self)
            let key = try cast(attr["key"], as: String.self)
            let value = try cast(attr["value"], as: [String: Any].self)
            byKey[key] = value
        }

        let arrayValue = try cast(byKey["tags"]?["arrayValue"], as: [String: Any].self)
        let arrayValues = try cast(arrayValue["values"], as: [Any].self)
        #expect(arrayValues.count == 2)

        let kvlistValue = try cast(byKey["labels"]?["kvlistValue"], as: [String: Any].self)
        let kvlistValues = try cast(kvlistValue["values"], as: [Any].self)
        let kvlistEntry = try cast(kvlistValues[0], as: [String: Any].self)
        #expect(kvlistEntry["key"] as? String == "env")
        let kvlistEntryValue = try cast(kvlistEntry["value"], as: [String: Any].self)
        #expect(kvlistEntryValue["stringValue"] as? String == "prod")
    }

    // MARK: - Helpers

    private func encodeJson<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        return try cast(object, as: [String: Any].self)
    }

    private func drillToLogRecord(_ json: [String: Any]) throws -> [String: Any] {
        let resourceLogs = try cast(json["resourceLogs"], as: [Any].self)
        let resourceLog = try cast(resourceLogs[0], as: [String: Any].self)
        let scopeLogs = try cast(resourceLog["scopeLogs"], as: [Any].self)
        let scopeLog = try cast(scopeLogs[0], as: [String: Any].self)
        let logRecords = try cast(scopeLog["logRecords"], as: [Any].self)
        return try cast(logRecords[0], as: [String: Any].self)
    }

    private func cast<T>(_ value: Any?, as _: T.Type) throws -> T {
        guard let typed = value as? T else {
            throw CastError(description: "Could not cast \(String(describing: value)) to \(T.self)")
        }
        return typed
    }
}

private struct CastError: Error, CustomStringConvertible {
    let description: String
}
