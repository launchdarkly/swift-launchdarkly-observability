/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

// Wire-format types shared by every OTLP/JSON signal (logs, traces, metrics).
//
// These follow the canonical Protobuf-to-JSON mapping
// (https://protobuf.dev/programming-guides/json/) with the OTLP-specific
// deviations called out in the OpenTelemetry specification:
//
// - 64-bit integers (e.g. `timeUnixNano`, `intValue`) are serialized as
//   JSON strings of decimal digits (see `OtlpJsonInt64`).
// - `traceId` / `spanId` are serialized as lowercase hexadecimal strings
//   (32 / 16 hex chars), NOT base64. Each signal handles that locally.
//
// Field names use the standard proto-JSON `lowerCamelCase` form so any
// compliant OTLP/HTTP receiver can decode the payload.

import Foundation

// MARK: - Resource & instrumentation scope

public struct OtlpJsonResource: Encodable {
    public var attributes: [OtlpJsonKeyValue]
    public var droppedAttributesCount: UInt32?

    public init(attributes: [OtlpJsonKeyValue],
                droppedAttributesCount: UInt32? = nil) {
        self.attributes = attributes
        self.droppedAttributesCount = droppedAttributesCount
    }
}

public struct OtlpJsonInstrumentationScope: Encodable {
    public var name: String
    public var version: String?
    public var attributes: [OtlpJsonKeyValue]?
    public var droppedAttributesCount: UInt32?

    public init(name: String,
                version: String? = nil,
                attributes: [OtlpJsonKeyValue]? = nil,
                droppedAttributesCount: UInt32? = nil) {
        self.name = name
        self.version = version
        self.attributes = attributes
        self.droppedAttributesCount = droppedAttributesCount
    }
}

// MARK: - AnyValue / KeyValue

public struct OtlpJsonKeyValue: Encodable {
    public var key: String
    public var value: OtlpJsonAnyValue

    public init(key: String, value: OtlpJsonAnyValue) {
        self.key = key
        self.value = value
    }
}

/// Mirrors `opentelemetry.proto.common.v1.AnyValue` which is a `oneof`.
/// Exactly one associated value is encoded for each instance.
public enum OtlpJsonAnyValue: Encodable {
    case string(String)
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case array([OtlpJsonAnyValue])
    case kvlist([OtlpJsonKeyValue])
    case bytes(Data)

    private enum CodingKeys: String, CodingKey {
        case stringValue
        case boolValue
        case intValue
        case doubleValue
        case arrayValue
        case kvlistValue
        case bytesValue
    }

    private struct ArrayValueWrapper: Encodable {
        let values: [OtlpJsonAnyValue]
    }

    private struct KeyValueListWrapper: Encodable {
        let values: [OtlpJsonKeyValue]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .string(value):
            try container.encode(value, forKey: .stringValue)
        case let .bool(value):
            try container.encode(value, forKey: .boolValue)
        case let .int(value):
            // 64-bit ints are encoded as decimal strings per proto3 JSON mapping.
            try container.encode(OtlpJsonInt64(value), forKey: .intValue)
        case let .double(value):
            try container.encode(value, forKey: .doubleValue)
        case let .array(values):
            try container.encode(ArrayValueWrapper(values: values), forKey: .arrayValue)
        case let .kvlist(values):
            try container.encode(KeyValueListWrapper(values: values), forKey: .kvlistValue)
        case let .bytes(data):
            try container.encode(data.base64EncodedString(), forKey: .bytesValue)
        }
    }
}

// MARK: - Int64 wrapper

/// 64-bit integer that serializes as a JSON string, as required by the
/// proto3 JSON mapping for `int64` / `uint64` / `fixed64` fields.
public struct OtlpJsonInt64: Encodable {
    public let value: Int64

    public init(_ value: Int64) {
        self.value = value
    }

    public init(_ value: UInt64) {
        // Saturate to Int64.max because OTLP timestamps are nanoseconds
        // and routinely fit in the positive Int64 range.
        if value > UInt64(Int64.max) {
            self.value = Int64.max
        } else {
            self.value = Int64(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(value))
    }
}
