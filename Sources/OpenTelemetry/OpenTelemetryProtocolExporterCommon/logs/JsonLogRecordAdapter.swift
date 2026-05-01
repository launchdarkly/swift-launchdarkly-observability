/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// Adapter that converts `ReadableLogRecord` instances into the OTLP/JSON
/// wire-format types declared in `OtlpJsonLogModels.swift`.
///
/// This is the JSON-encoded counterpart of `LogRecordAdapter`, which produces
/// SwiftProtobuf message types instead.
public enum JsonLogRecordAdapter {
    public static func toJsonRequest(logRecordList: [ReadableLogRecord]) -> OtlpJsonExportLogsServiceRequest {
        return OtlpJsonExportLogsServiceRequest(resourceLogs: toResourceLogs(logRecordList: logRecordList))
    }

    public static func toResourceLogs(logRecordList: [ReadableLogRecord]) -> [OtlpJsonResourceLogs] {
        let grouped = groupByResourceAndScope(logRecordList: logRecordList)
        return grouped.map { resource, scopes in
            let scopeLogs: [OtlpJsonScopeLogs] = scopes.map { scopeInfo, records in
                OtlpJsonScopeLogs(
                    scope: toJsonInstrumentationScope(scopeInfo),
                    logRecords: records,
                    schemaUrl: scopeInfo.schemaUrl
                )
            }
            return OtlpJsonResourceLogs(
                resource: toJsonResource(resource),
                scopeLogs: scopeLogs
            )
        }
    }

    private static func groupByResourceAndScope(
        logRecordList: [ReadableLogRecord]
    ) -> [Resource: [InstrumentationScopeInfo: [OtlpJsonLogRecord]]] {
        var result = [Resource: [InstrumentationScopeInfo: [OtlpJsonLogRecord]]]()
        for record in logRecordList {
            result[
                record.resource,
                default: [InstrumentationScopeInfo: [OtlpJsonLogRecord]]()
            ][
                record.instrumentationScopeInfo,
                default: [OtlpJsonLogRecord]()
            ].append(toJsonLogRecord(record))
        }
        return result
    }

    static func toJsonLogRecord(_ logRecord: ReadableLogRecord) -> OtlpJsonLogRecord {
        var json = OtlpJsonLogRecord()

        json.timeUnixNano = OtlpJsonInt64(logRecord.timestamp.timeIntervalSince1970.toNanoseconds)

        if let observed = logRecord.observedTimestamp {
            json.observedTimeUnixNano = OtlpJsonInt64(observed.timeIntervalSince1970.toNanoseconds)
        }

        if let body = logRecord.body {
            json.body = toJsonAnyValue(body)
        }

        if let severity = logRecord.severity {
            json.severityNumber = Int32(severity.rawValue)
            json.severityText = severity.description
        }

        if let context = logRecord.spanContext {
            json.traceId = context.traceId.hexString
            json.spanId = context.spanId.hexString
            json.flags = UInt32(context.traceFlags.byte)
        }

        if let eventName = logRecord.eventName {
            json.eventName = eventName
        }

        if !logRecord.attributes.isEmpty {
            json.attributes = logRecord.attributes.map {
                toJsonKeyValue(key: $0.key, value: $0.value)
            }
        }

        return json
    }

    // MARK: - Resource & scope

    static func toJsonResource(_ resource: Resource) -> OtlpJsonResource {
        OtlpJsonResource(
            attributes: resource.attributes.map { toJsonKeyValue(key: $0.key, value: $0.value) }
        )
    }

    static func toJsonInstrumentationScope(_ scope: InstrumentationScopeInfo) -> OtlpJsonInstrumentationScope {
        OtlpJsonInstrumentationScope(
            name: scope.name,
            version: scope.version,
            attributes: scope.attributes?.map { toJsonKeyValue(key: $0.key, value: $0.value) }
        )
    }

    // MARK: - AnyValue / KeyValue

    static func toJsonKeyValue(key: String, value: AttributeValue) -> OtlpJsonKeyValue {
        OtlpJsonKeyValue(key: key, value: toJsonAnyValue(value))
    }

    static func toJsonAnyValue(_ value: AttributeValue) -> OtlpJsonAnyValue {
        switch value {
        case let .string(value):
            return .string(value)
        case let .bool(value):
            return .bool(value)
        case let .int(value):
            return .int(Int64(value))
        case let .double(value):
            return .double(value)
        case let .stringArray(values):
            return .array(values.map { .string($0) })
        case let .boolArray(values):
            return .array(values.map { .bool($0) })
        case let .intArray(values):
            return .array(values.map { .int(Int64($0)) })
        case let .doubleArray(values):
            return .array(values.map { .double($0) })
        case let .array(array):
            return .array(array.values.map(toJsonAnyValue))
        case let .set(set):
            return .kvlist(set.labels.map { toJsonKeyValue(key: $0.key, value: $0.value) })
        }
    }
}
