/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// Conversions from OpenTelemetry SDK types into the OTLP/JSON wire-format
/// types declared in `OtlpJsonCommonModels.swift`. Reused by every
/// per-signal adapter (logs, traces, …).
public enum JsonCommonAdapter {
    public static func toJsonResource(_ resource: Resource) -> OtlpJsonResource {
        OtlpJsonResource(
            attributes: resource.attributes.map { toJsonKeyValue(key: $0.key, value: $0.value) }
        )
    }

    public static func toJsonInstrumentationScope(_ scope: InstrumentationScopeInfo) -> OtlpJsonInstrumentationScope {
        OtlpJsonInstrumentationScope(
            name: scope.name,
            version: scope.version,
            attributes: scope.attributes?.map { toJsonKeyValue(key: $0.key, value: $0.value) }
        )
    }

    public static func toJsonAttributes(_ attributes: [String: AttributeValue]) -> [OtlpJsonKeyValue] {
        attributes.map { toJsonKeyValue(key: $0.key, value: $0.value) }
    }

    public static func toJsonKeyValue(key: String, value: AttributeValue) -> OtlpJsonKeyValue {
        OtlpJsonKeyValue(key: key, value: toJsonAnyValue(value))
    }

    public static func toJsonAnyValue(_ value: AttributeValue) -> OtlpJsonAnyValue {
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
