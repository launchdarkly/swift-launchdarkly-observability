/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

// OTLP/JSON wire-format types for the logs signal.
// Common pieces (Resource, InstrumentationScope, KeyValue, AnyValue, Int64
// wrapper) live in `OtlpJsonCommonModels.swift`.

import Foundation

public struct OtlpJsonExportLogsServiceRequest: Encodable {
    public var resourceLogs: [OtlpJsonResourceLogs]

    public init(resourceLogs: [OtlpJsonResourceLogs]) {
        self.resourceLogs = resourceLogs
    }
}

public struct OtlpJsonResourceLogs: Encodable {
    public var resource: OtlpJsonResource?
    public var scopeLogs: [OtlpJsonScopeLogs]
    public var schemaUrl: String?

    public init(resource: OtlpJsonResource?,
                scopeLogs: [OtlpJsonScopeLogs],
                schemaUrl: String? = nil) {
        self.resource = resource
        self.scopeLogs = scopeLogs
        self.schemaUrl = schemaUrl
    }
}

public struct OtlpJsonScopeLogs: Encodable {
    public var scope: OtlpJsonInstrumentationScope?
    public var logRecords: [OtlpJsonLogRecord]
    public var schemaUrl: String?

    public init(scope: OtlpJsonInstrumentationScope?,
                logRecords: [OtlpJsonLogRecord],
                schemaUrl: String? = nil) {
        self.scope = scope
        self.logRecords = logRecords
        self.schemaUrl = schemaUrl
    }
}

public struct OtlpJsonLogRecord: Encodable {
    public var timeUnixNano: OtlpJsonInt64?
    public var observedTimeUnixNano: OtlpJsonInt64?
    public var severityNumber: Int32?
    public var severityText: String?
    public var body: OtlpJsonAnyValue?
    public var attributes: [OtlpJsonKeyValue]?
    public var droppedAttributesCount: UInt32?
    public var flags: UInt32?
    /// Lowercase hex string (32 chars), per OTLP/JSON spec deviation.
    public var traceId: String?
    /// Lowercase hex string (16 chars), per OTLP/JSON spec deviation.
    public var spanId: String?
    public var eventName: String?
}
