/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

// OTLP/JSON wire-format types for the traces signal.
// Common pieces (Resource, InstrumentationScope, KeyValue, AnyValue, Int64
// wrapper) live in `OtlpJsonCommonModels.swift`.

import Foundation

// MARK: - Top-level export request

public struct OtlpJsonExportTraceServiceRequest: Encodable {
    public var resourceSpans: [OtlpJsonResourceSpans]

    public init(resourceSpans: [OtlpJsonResourceSpans]) {
        self.resourceSpans = resourceSpans
    }
}

public struct OtlpJsonResourceSpans: Encodable {
    public var resource: OtlpJsonResource?
    public var scopeSpans: [OtlpJsonScopeSpans]
    public var schemaUrl: String?

    public init(resource: OtlpJsonResource?,
                scopeSpans: [OtlpJsonScopeSpans],
                schemaUrl: String? = nil) {
        self.resource = resource
        self.scopeSpans = scopeSpans
        self.schemaUrl = schemaUrl
    }
}

public struct OtlpJsonScopeSpans: Encodable {
    public var scope: OtlpJsonInstrumentationScope?
    public var spans: [OtlpJsonSpan]
    public var schemaUrl: String?

    public init(scope: OtlpJsonInstrumentationScope?,
                spans: [OtlpJsonSpan],
                schemaUrl: String? = nil) {
        self.scope = scope
        self.spans = spans
        self.schemaUrl = schemaUrl
    }
}

// MARK: - Span

public struct OtlpJsonSpan: Encodable {
    /// Lowercase hex string (32 chars), per OTLP/JSON spec deviation.
    public var traceId: String
    /// Lowercase hex string (16 chars), per OTLP/JSON spec deviation.
    public var spanId: String
    public var traceState: String?
    /// Lowercase hex string (16 chars), per OTLP/JSON spec deviation.
    public var parentSpanId: String?
    public var flags: UInt32?
    public var name: String
    public var kind: OtlpJsonSpanKind
    public var startTimeUnixNano: OtlpJsonInt64
    public var endTimeUnixNano: OtlpJsonInt64
    public var attributes: [OtlpJsonKeyValue]?
    public var droppedAttributesCount: UInt32?
    public var events: [Event]?
    public var droppedEventsCount: UInt32?
    public var links: [Link]?
    public var droppedLinksCount: UInt32?
    public var status: OtlpJsonStatus?

    public struct Event: Encodable {
        public var timeUnixNano: OtlpJsonInt64
        public var name: String
        public var attributes: [OtlpJsonKeyValue]?
        public var droppedAttributesCount: UInt32?

        public init(timeUnixNano: OtlpJsonInt64,
                    name: String,
                    attributes: [OtlpJsonKeyValue]? = nil,
                    droppedAttributesCount: UInt32? = nil) {
            self.timeUnixNano = timeUnixNano
            self.name = name
            self.attributes = attributes
            self.droppedAttributesCount = droppedAttributesCount
        }
    }

    public struct Link: Encodable {
        /// Lowercase hex string (32 chars).
        public var traceId: String
        /// Lowercase hex string (16 chars).
        public var spanId: String
        public var traceState: String?
        public var attributes: [OtlpJsonKeyValue]?
        public var droppedAttributesCount: UInt32?
        public var flags: UInt32?

        public init(traceId: String,
                    spanId: String,
                    traceState: String? = nil,
                    attributes: [OtlpJsonKeyValue]? = nil,
                    droppedAttributesCount: UInt32? = nil,
                    flags: UInt32? = nil) {
            self.traceId = traceId
            self.spanId = spanId
            self.traceState = traceState
            self.attributes = attributes
            self.droppedAttributesCount = droppedAttributesCount
            self.flags = flags
        }
    }
}

// MARK: - Span kind & status

/// Encoded as the proto-JSON enum string form (e.g. `"SPAN_KIND_CLIENT"`),
/// which is the canonical representation per the proto3 JSON mapping.
public enum OtlpJsonSpanKind: String, Encodable {
    case unspecified = "SPAN_KIND_UNSPECIFIED"
    case `internal` = "SPAN_KIND_INTERNAL"
    case server = "SPAN_KIND_SERVER"
    case client = "SPAN_KIND_CLIENT"
    case producer = "SPAN_KIND_PRODUCER"
    case consumer = "SPAN_KIND_CONSUMER"
}

public struct OtlpJsonStatus: Encodable {
    public var message: String?
    public var code: OtlpJsonStatusCode

    public init(code: OtlpJsonStatusCode, message: String? = nil) {
        self.code = code
        self.message = message
    }
}

public enum OtlpJsonStatusCode: String, Encodable {
    case unset = "STATUS_CODE_UNSET"
    case ok = "STATUS_CODE_OK"
    case error = "STATUS_CODE_ERROR"
}
