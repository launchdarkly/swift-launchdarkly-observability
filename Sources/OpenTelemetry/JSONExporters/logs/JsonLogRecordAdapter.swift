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
/// JSON-encoded counterpart of `LogRecordAdapter`, which produces
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
                    scope: JsonCommonAdapter.toJsonInstrumentationScope(scopeInfo),
                    logRecords: records,
                    schemaUrl: scopeInfo.schemaUrl
                )
            }
            return OtlpJsonResourceLogs(
                resource: JsonCommonAdapter.toJsonResource(resource),
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
            json.body = JsonCommonAdapter.toJsonAnyValue(body)
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
            json.attributes = JsonCommonAdapter.toJsonAttributes(logRecord.attributes)
        }

        return json
    }
}
