/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// Adapter that converts `MetricData` instances into the OTLP/JSON
/// wire-format types declared in `OtlpJsonMetricModels.swift`.
///
/// JSON-encoded counterpart of `MetricsAdapter`, which produces
/// SwiftProtobuf message types instead.
public enum JsonMetricsAdapter {
    public static func toJsonRequest(metricData: [MetricData]) -> OtlpJsonExportMetricsServiceRequest {
        return OtlpJsonExportMetricsServiceRequest(resourceMetrics: toResourceMetrics(metricData: metricData))
    }

    public static func toResourceMetrics(metricData: [MetricData]) -> [OtlpJsonResourceMetrics] {
        let grouped = groupByResourceAndScope(metricData: metricData)
        return grouped.map { resource, scopes in
            let scopeMetrics: [OtlpJsonScopeMetrics] = scopes.map { scopeInfo, metrics in
                OtlpJsonScopeMetrics(
                    scope: JsonCommonAdapter.toJsonInstrumentationScope(scopeInfo),
                    metrics: metrics,
                    schemaUrl: scopeInfo.schemaUrl
                )
            }
            return OtlpJsonResourceMetrics(
                resource: JsonCommonAdapter.toJsonResource(resource),
                scopeMetrics: scopeMetrics
            )
        }
    }

    private static func groupByResourceAndScope(
        metricData: [MetricData]
    ) -> [Resource: [InstrumentationScopeInfo: [OtlpJsonMetric]]] {
        var result = [Resource: [InstrumentationScopeInfo: [OtlpJsonMetric]]]()
        for metric in metricData {
            guard let json = toJsonMetric(metric) else { continue }
            result[
                metric.resource,
                default: [InstrumentationScopeInfo: [OtlpJsonMetric]]()
            ][
                metric.instrumentationScopeInfo,
                default: [OtlpJsonMetric]()
            ].append(json)
        }
        return result
    }

    public static func toJsonMetric(_ metric: MetricData) -> OtlpJsonMetric? {
        guard !metric.data.points.isEmpty else { return nil }
        guard let data = toJsonMetricData(metric) else { return nil }
        return OtlpJsonMetric(
            name: metric.name,
            description: metric.description.isEmpty ? nil : metric.description,
            unit: metric.unit.isEmpty ? nil : metric.unit,
            data: data
        )
    }

    private static func toJsonMetricData(_ metric: MetricData) -> OtlpJsonMetric.Data? {
        let temporality = toJsonAggregationTemporality(metric.data.aggregationTemporality)

        switch metric.type {
        case .LongGauge:
            let points = metric.data.points.compactMap { $0 as? LongPointData }
                .map { toJsonNumberDataPoint($0, value: .int(Int64($0.value))) }
            return .gauge(OtlpJsonGauge(dataPoints: points))

        case .DoubleGauge:
            let points = metric.data.points.compactMap { $0 as? DoublePointData }
                .map { toJsonNumberDataPoint($0, value: .double($0.value)) }
            return .gauge(OtlpJsonGauge(dataPoints: points))

        case .LongSum:
            let points = metric.data.points.compactMap { $0 as? LongPointData }
                .map { toJsonNumberDataPoint($0, value: .int(Int64($0.value))) }
            return .sum(OtlpJsonSum(
                dataPoints: points,
                aggregationTemporality: temporality,
                isMonotonic: metric.isMonotonic
            ))

        case .DoubleSum:
            let points = metric.data.points.compactMap { $0 as? DoublePointData }
                .map { toJsonNumberDataPoint($0, value: .double($0.value)) }
            return .sum(OtlpJsonSum(
                dataPoints: points,
                aggregationTemporality: temporality,
                isMonotonic: metric.isMonotonic
            ))

        case .Histogram:
            let points = metric.data.points.compactMap { $0 as? HistogramPointData }
                .map(toJsonHistogramDataPoint)
            return .histogram(OtlpJsonHistogram(
                dataPoints: points,
                aggregationTemporality: temporality
            ))

        case .ExponentialHistogram:
            let points = metric.data.points.compactMap { $0 as? ExponentialHistogramPointData }
                .map(toJsonExponentialHistogramDataPoint)
            return .exponentialHistogram(OtlpJsonExponentialHistogram(
                dataPoints: points,
                aggregationTemporality: temporality
            ))

        case .Summary:
            let points = metric.data.points.compactMap { $0 as? SummaryPointData }
                .map(toJsonSummaryDataPoint)
            return .summary(OtlpJsonSummary(dataPoints: points))
        }
    }

    // MARK: - Per-point conversions

    static func toJsonNumberDataPoint(_ point: PointData,
                                      value: OtlpJsonNumberValue) -> OtlpJsonNumberDataPoint {
        OtlpJsonNumberDataPoint(
            attributes: jsonAttributes(point.attributes),
            startTimeUnixNano: OtlpJsonInt64(point.startEpochNanos),
            timeUnixNano: OtlpJsonInt64(point.endEpochNanos),
            value: value,
            exemplars: jsonExemplars(point.exemplars)
        )
    }

    static func toJsonHistogramDataPoint(_ point: HistogramPointData) -> OtlpJsonHistogramDataPoint {
        OtlpJsonHistogramDataPoint(
            attributes: jsonAttributes(point.attributes),
            startTimeUnixNano: OtlpJsonInt64(point.startEpochNanos),
            timeUnixNano: OtlpJsonInt64(point.endEpochNanos),
            count: OtlpJsonInt64(point.count),
            sum: point.sum,
            bucketCounts: point.counts.map { OtlpJsonInt64(Int64($0)) },
            explicitBounds: point.boundaries,
            exemplars: jsonExemplars(point.exemplars),
            min: point.hasMin ? point.min : nil,
            max: point.hasMax ? point.max : nil
        )
    }

    static func toJsonExponentialHistogramDataPoint(
        _ point: ExponentialHistogramPointData
    ) -> OtlpJsonExponentialHistogramDataPoint {
        OtlpJsonExponentialHistogramDataPoint(
            attributes: jsonAttributes(point.attributes),
            startTimeUnixNano: OtlpJsonInt64(point.startEpochNanos),
            timeUnixNano: OtlpJsonInt64(point.endEpochNanos),
            count: OtlpJsonInt64(Int64(point.count)),
            sum: point.sum,
            scale: Int32(point.scale),
            zeroCount: OtlpJsonInt64(point.zeroCount),
            positive: toJsonBuckets(point.positiveBuckets),
            negative: toJsonBuckets(point.negativeBuckets),
            exemplars: jsonExemplars(point.exemplars),
            min: point.hasMin ? point.min : nil,
            max: point.hasMax ? point.max : nil
        )
    }

    static func toJsonSummaryDataPoint(_ point: SummaryPointData) -> OtlpJsonSummaryDataPoint {
        let quantiles: [OtlpJsonSummaryDataPoint.ValueAtQuantile] = point.values.map {
            .init(quantile: $0.quantile, value: $0.value)
        }
        return OtlpJsonSummaryDataPoint(
            attributes: jsonAttributes(point.attributes),
            startTimeUnixNano: OtlpJsonInt64(point.startEpochNanos),
            timeUnixNano: OtlpJsonInt64(point.endEpochNanos),
            count: OtlpJsonInt64(point.count),
            sum: point.sum,
            quantileValues: quantiles.isEmpty ? nil : quantiles
        )
    }

    // MARK: - Exemplars / buckets / temporality

    static func jsonExemplars(_ exemplars: [ExemplarData]) -> [OtlpJsonExemplar]? {
        guard !exemplars.isEmpty else { return nil }
        return exemplars.map(toJsonExemplar)
    }

    static func toJsonExemplar(_ exemplar: ExemplarData) -> OtlpJsonExemplar {
        let value: OtlpJsonNumberValue
        if let double = exemplar as? DoubleExemplarData {
            value = .double(double.value)
        } else if let long = exemplar as? LongExemplarData {
            value = .int(Int64(long.value))
        } else {
            // Default to zero so we still emit a structurally valid payload.
            value = .double(0)
        }

        return OtlpJsonExemplar(
            filteredAttributes: jsonAttributes(exemplar.filteredAttributes),
            timeUnixNano: OtlpJsonInt64(exemplar.epochNanos),
            value: value,
            traceId: exemplar.spanContext?.traceId.hexString,
            spanId: exemplar.spanContext?.spanId.hexString
        )
    }

    static func toJsonBuckets(_ buckets: ExponentialHistogramBuckets) -> OtlpJsonExponentialHistogramDataPoint.Buckets {
        OtlpJsonExponentialHistogramDataPoint.Buckets(
            offset: Int32(buckets.offset),
            bucketCounts: buckets.bucketCounts.map { OtlpJsonInt64($0) }
        )
    }

    static func toJsonAggregationTemporality(_ temporality: AggregationTemporality) -> OtlpJsonAggregationTemporality {
        switch temporality {
        case .delta: return .delta
        case .cumulative: return .cumulative
        }
    }

    private static func jsonAttributes(_ attributes: [String: AttributeValue]) -> [OtlpJsonKeyValue]? {
        guard !attributes.isEmpty else { return nil }
        return JsonCommonAdapter.toJsonAttributes(attributes)
    }
}
