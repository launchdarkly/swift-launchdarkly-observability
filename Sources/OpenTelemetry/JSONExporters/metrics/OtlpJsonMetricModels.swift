/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

// OTLP/JSON wire-format types for the metrics signal.
// Common pieces (Resource, InstrumentationScope, KeyValue, AnyValue, Int64
// wrapper) live in `OtlpJsonCommonModels.swift`.

import Foundation

// MARK: - Top-level export request

public struct OtlpJsonExportMetricsServiceRequest: Encodable {
    public var resourceMetrics: [OtlpJsonResourceMetrics]

    public init(resourceMetrics: [OtlpJsonResourceMetrics]) {
        self.resourceMetrics = resourceMetrics
    }
}

public struct OtlpJsonResourceMetrics: Encodable {
    public var resource: OtlpJsonResource?
    public var scopeMetrics: [OtlpJsonScopeMetrics]
    public var schemaUrl: String?

    public init(resource: OtlpJsonResource?,
                scopeMetrics: [OtlpJsonScopeMetrics],
                schemaUrl: String? = nil) {
        self.resource = resource
        self.scopeMetrics = scopeMetrics
        self.schemaUrl = schemaUrl
    }
}

public struct OtlpJsonScopeMetrics: Encodable {
    public var scope: OtlpJsonInstrumentationScope?
    public var metrics: [OtlpJsonMetric]
    public var schemaUrl: String?

    public init(scope: OtlpJsonInstrumentationScope?,
                metrics: [OtlpJsonMetric],
                schemaUrl: String? = nil) {
        self.scope = scope
        self.metrics = metrics
        self.schemaUrl = schemaUrl
    }
}

// MARK: - Metric

/// Mirrors `opentelemetry.proto.metrics.v1.Metric`. The proto `data` field
/// is a `oneof`, so we encode exactly one of the per-type containers
/// (`gauge` / `sum` / `histogram` / `exponentialHistogram` / `summary`).
public struct OtlpJsonMetric: Encodable {
    public var name: String
    public var description: String?
    public var unit: String?
    public var data: Data

    public enum Data {
        case gauge(OtlpJsonGauge)
        case sum(OtlpJsonSum)
        case histogram(OtlpJsonHistogram)
        case exponentialHistogram(OtlpJsonExponentialHistogram)
        case summary(OtlpJsonSummary)
    }

    public init(name: String,
                description: String? = nil,
                unit: String? = nil,
                data: Data) {
        self.name = name
        self.description = description
        self.unit = unit
        self.data = data
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case unit
        case gauge
        case sum
        case histogram
        case exponentialHistogram
        case summary
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(unit, forKey: .unit)

        switch data {
        case let .gauge(value):
            try container.encode(value, forKey: .gauge)
        case let .sum(value):
            try container.encode(value, forKey: .sum)
        case let .histogram(value):
            try container.encode(value, forKey: .histogram)
        case let .exponentialHistogram(value):
            try container.encode(value, forKey: .exponentialHistogram)
        case let .summary(value):
            try container.encode(value, forKey: .summary)
        }
    }
}

// MARK: - Per-type containers

public struct OtlpJsonGauge: Encodable {
    public var dataPoints: [OtlpJsonNumberDataPoint]

    public init(dataPoints: [OtlpJsonNumberDataPoint]) {
        self.dataPoints = dataPoints
    }
}

public struct OtlpJsonSum: Encodable {
    public var dataPoints: [OtlpJsonNumberDataPoint]
    public var aggregationTemporality: OtlpJsonAggregationTemporality
    public var isMonotonic: Bool

    public init(dataPoints: [OtlpJsonNumberDataPoint],
                aggregationTemporality: OtlpJsonAggregationTemporality,
                isMonotonic: Bool) {
        self.dataPoints = dataPoints
        self.aggregationTemporality = aggregationTemporality
        self.isMonotonic = isMonotonic
    }
}

public struct OtlpJsonHistogram: Encodable {
    public var dataPoints: [OtlpJsonHistogramDataPoint]
    public var aggregationTemporality: OtlpJsonAggregationTemporality

    public init(dataPoints: [OtlpJsonHistogramDataPoint],
                aggregationTemporality: OtlpJsonAggregationTemporality) {
        self.dataPoints = dataPoints
        self.aggregationTemporality = aggregationTemporality
    }
}

public struct OtlpJsonExponentialHistogram: Encodable {
    public var dataPoints: [OtlpJsonExponentialHistogramDataPoint]
    public var aggregationTemporality: OtlpJsonAggregationTemporality

    public init(dataPoints: [OtlpJsonExponentialHistogramDataPoint],
                aggregationTemporality: OtlpJsonAggregationTemporality) {
        self.dataPoints = dataPoints
        self.aggregationTemporality = aggregationTemporality
    }
}

public struct OtlpJsonSummary: Encodable {
    public var dataPoints: [OtlpJsonSummaryDataPoint]

    public init(dataPoints: [OtlpJsonSummaryDataPoint]) {
        self.dataPoints = dataPoints
    }
}

// MARK: - Data points

public struct OtlpJsonNumberDataPoint: Encodable {
    public var attributes: [OtlpJsonKeyValue]?
    public var startTimeUnixNano: OtlpJsonInt64
    public var timeUnixNano: OtlpJsonInt64
    public var value: OtlpJsonNumberValue
    public var exemplars: [OtlpJsonExemplar]?
    public var flags: UInt32?

    public init(attributes: [OtlpJsonKeyValue]?,
                startTimeUnixNano: OtlpJsonInt64,
                timeUnixNano: OtlpJsonInt64,
                value: OtlpJsonNumberValue,
                exemplars: [OtlpJsonExemplar]? = nil,
                flags: UInt32? = nil) {
        self.attributes = attributes
        self.startTimeUnixNano = startTimeUnixNano
        self.timeUnixNano = timeUnixNano
        self.value = value
        self.exemplars = exemplars
        self.flags = flags
    }

    private enum CodingKeys: String, CodingKey {
        case attributes
        case startTimeUnixNano
        case timeUnixNano
        case asInt
        case asDouble
        case exemplars
        case flags
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(attributes, forKey: .attributes)
        try container.encode(startTimeUnixNano, forKey: .startTimeUnixNano)
        try container.encode(timeUnixNano, forKey: .timeUnixNano)
        try container.encodeIfPresent(exemplars, forKey: .exemplars)
        try container.encodeIfPresent(flags, forKey: .flags)
        switch value {
        case let .int(int):
            try container.encode(OtlpJsonInt64(int), forKey: .asInt)
        case let .double(double):
            try container.encode(double, forKey: .asDouble)
        }
    }
}

public struct OtlpJsonHistogramDataPoint: Encodable {
    public var attributes: [OtlpJsonKeyValue]?
    public var startTimeUnixNano: OtlpJsonInt64
    public var timeUnixNano: OtlpJsonInt64
    /// uint64 → encoded as a JSON string per proto3 mapping.
    public var count: OtlpJsonInt64
    public var sum: Double?
    /// Each entry is uint64 → encoded as a JSON string.
    public var bucketCounts: [OtlpJsonInt64]?
    public var explicitBounds: [Double]?
    public var exemplars: [OtlpJsonExemplar]?
    public var flags: UInt32?
    public var min: Double?
    public var max: Double?

    public init(attributes: [OtlpJsonKeyValue]?,
                startTimeUnixNano: OtlpJsonInt64,
                timeUnixNano: OtlpJsonInt64,
                count: OtlpJsonInt64,
                sum: Double? = nil,
                bucketCounts: [OtlpJsonInt64]? = nil,
                explicitBounds: [Double]? = nil,
                exemplars: [OtlpJsonExemplar]? = nil,
                flags: UInt32? = nil,
                min: Double? = nil,
                max: Double? = nil) {
        self.attributes = attributes
        self.startTimeUnixNano = startTimeUnixNano
        self.timeUnixNano = timeUnixNano
        self.count = count
        self.sum = sum
        self.bucketCounts = bucketCounts
        self.explicitBounds = explicitBounds
        self.exemplars = exemplars
        self.flags = flags
        self.min = min
        self.max = max
    }
}

public struct OtlpJsonExponentialHistogramDataPoint: Encodable {
    public var attributes: [OtlpJsonKeyValue]?
    public var startTimeUnixNano: OtlpJsonInt64
    public var timeUnixNano: OtlpJsonInt64
    public var count: OtlpJsonInt64
    public var sum: Double?
    public var scale: Int32
    public var zeroCount: OtlpJsonInt64?
    public var positive: Buckets?
    public var negative: Buckets?
    public var flags: UInt32?
    public var exemplars: [OtlpJsonExemplar]?
    public var min: Double?
    public var max: Double?

    public init(attributes: [OtlpJsonKeyValue]?,
                startTimeUnixNano: OtlpJsonInt64,
                timeUnixNano: OtlpJsonInt64,
                count: OtlpJsonInt64,
                sum: Double? = nil,
                scale: Int32,
                zeroCount: OtlpJsonInt64? = nil,
                positive: Buckets? = nil,
                negative: Buckets? = nil,
                flags: UInt32? = nil,
                exemplars: [OtlpJsonExemplar]? = nil,
                min: Double? = nil,
                max: Double? = nil) {
        self.attributes = attributes
        self.startTimeUnixNano = startTimeUnixNano
        self.timeUnixNano = timeUnixNano
        self.count = count
        self.sum = sum
        self.scale = scale
        self.zeroCount = zeroCount
        self.positive = positive
        self.negative = negative
        self.flags = flags
        self.exemplars = exemplars
        self.min = min
        self.max = max
    }

    public struct Buckets: Encodable {
        public var offset: Int32
        public var bucketCounts: [OtlpJsonInt64]

        public init(offset: Int32, bucketCounts: [OtlpJsonInt64]) {
            self.offset = offset
            self.bucketCounts = bucketCounts
        }
    }
}

public struct OtlpJsonSummaryDataPoint: Encodable {
    public var attributes: [OtlpJsonKeyValue]?
    public var startTimeUnixNano: OtlpJsonInt64
    public var timeUnixNano: OtlpJsonInt64
    public var count: OtlpJsonInt64
    public var sum: Double
    public var quantileValues: [ValueAtQuantile]?
    public var flags: UInt32?

    public init(attributes: [OtlpJsonKeyValue]?,
                startTimeUnixNano: OtlpJsonInt64,
                timeUnixNano: OtlpJsonInt64,
                count: OtlpJsonInt64,
                sum: Double,
                quantileValues: [ValueAtQuantile]? = nil,
                flags: UInt32? = nil) {
        self.attributes = attributes
        self.startTimeUnixNano = startTimeUnixNano
        self.timeUnixNano = timeUnixNano
        self.count = count
        self.sum = sum
        self.quantileValues = quantileValues
        self.flags = flags
    }

    public struct ValueAtQuantile: Encodable {
        public var quantile: Double
        public var value: Double

        public init(quantile: Double, value: Double) {
            self.quantile = quantile
            self.value = value
        }
    }
}

// MARK: - Exemplar & supporting types

public struct OtlpJsonExemplar: Encodable {
    public var filteredAttributes: [OtlpJsonKeyValue]?
    public var timeUnixNano: OtlpJsonInt64
    public var value: OtlpJsonNumberValue
    /// Lowercase hex string (32 chars), per OTLP/JSON spec deviation.
    public var traceId: String?
    /// Lowercase hex string (16 chars), per OTLP/JSON spec deviation.
    public var spanId: String?

    public init(filteredAttributes: [OtlpJsonKeyValue]?,
                timeUnixNano: OtlpJsonInt64,
                value: OtlpJsonNumberValue,
                traceId: String? = nil,
                spanId: String? = nil) {
        self.filteredAttributes = filteredAttributes
        self.timeUnixNano = timeUnixNano
        self.value = value
        self.traceId = traceId
        self.spanId = spanId
    }

    private enum CodingKeys: String, CodingKey {
        case filteredAttributes
        case timeUnixNano
        case asInt
        case asDouble
        case traceId
        case spanId
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(filteredAttributes, forKey: .filteredAttributes)
        try container.encode(timeUnixNano, forKey: .timeUnixNano)
        try container.encodeIfPresent(traceId, forKey: .traceId)
        try container.encodeIfPresent(spanId, forKey: .spanId)
        switch value {
        case let .int(int):
            try container.encode(OtlpJsonInt64(int), forKey: .asInt)
        case let .double(double):
            try container.encode(double, forKey: .asDouble)
        }
    }
}

/// Mirrors the `oneof` numeric value used by both `NumberDataPoint` and
/// `Exemplar` in the OTLP proto.
public enum OtlpJsonNumberValue {
    case int(Int64)
    case double(Double)
}

/// Encoded as the proto-JSON enum string form.
public enum OtlpJsonAggregationTemporality: String, Encodable {
    case unspecified = "AGGREGATION_TEMPORALITY_UNSPECIFIED"
    case delta = "AGGREGATION_TEMPORALITY_DELTA"
    case cumulative = "AGGREGATION_TEMPORALITY_CUMULATIVE"
}
