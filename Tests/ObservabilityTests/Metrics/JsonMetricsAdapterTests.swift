import Foundation
import Testing
import OpenTelemetryApi
@testable import OpenTelemetrySdk
@testable import JSONExporters

struct JsonMetricsAdapterTests {
    private let resource = Resource(attributes: ["service.name": .string("test-service")])
    private let scope = InstrumentationScopeInfo(name: "test-scope", version: "1.2.3")
    private let startNanos: UInt64 = 1_700_000_000_000_000_000
    private let endNanos: UInt64 = 1_700_000_001_000_000_000

    @Test("Encodes LongSum as a sum container with asInt and AGGREGATION_TEMPORALITY_DELTA")
    func encodesLongSum() throws {
        let point = LongPointData(
            startEpochNanos: startNanos,
            endEpochNanos: endNanos,
            attributes: ["host": .string("h1")],
            exemplars: [],
            value: 42
        )

        let metric = MetricData(
            resource: resource,
            instrumentationScopeInfo: scope,
            name: "requests.total",
            description: "Total request count",
            unit: "1",
            type: .LongSum,
            isMonotonic: true,
            data: SumData(aggregationTemporality: .delta, points: [point])
        )

        let request = JsonMetricsAdapter.toJsonRequest(metricData: [metric])
        let json = try JsonTestHelpers.encodeJson(request)
        let metricJson = try drillToMetric(json)

        #expect(metricJson["name"] as? String == "requests.total")
        #expect(metricJson["description"] as? String == "Total request count")
        #expect(metricJson["unit"] as? String == "1")

        let sum = try JsonTestHelpers.cast(metricJson["sum"], as: [String: Any].self)
        #expect(sum["aggregationTemporality"] as? String == "AGGREGATION_TEMPORALITY_DELTA")
        #expect(sum["isMonotonic"] as? Bool == true)

        let dataPoints = try JsonTestHelpers.cast(sum["dataPoints"], as: [Any].self)
        let dataPoint = try JsonTestHelpers.cast(dataPoints[0], as: [String: Any].self)
        // 64-bit ints serialize as decimal strings.
        #expect(dataPoint["startTimeUnixNano"] as? String == "1700000000000000000")
        #expect(dataPoint["timeUnixNano"] as? String == "1700000001000000000")
        #expect(dataPoint["asInt"] as? String == "42")

        let attributes = try JsonTestHelpers.cast(dataPoint["attributes"], as: [Any].self)
        let attribute = try JsonTestHelpers.cast(attributes[0], as: [String: Any].self)
        #expect(attribute["key"] as? String == "host")
    }

    @Test("Encodes DoubleGauge as a gauge container with asDouble")
    func encodesDoubleGauge() throws {
        let point = DoublePointData(
            startEpochNanos: startNanos,
            endEpochNanos: endNanos,
            attributes: [:],
            exemplars: [],
            value: 12.5
        )

        let metric = MetricData(
            resource: resource,
            instrumentationScopeInfo: scope,
            name: "cpu.usage",
            description: "",
            unit: "",
            type: .DoubleGauge,
            isMonotonic: false,
            data: GaugeData(aggregationTemporality: .cumulative, points: [point])
        )

        let request = JsonMetricsAdapter.toJsonRequest(metricData: [metric])
        let json = try JsonTestHelpers.encodeJson(request)
        let metricJson = try drillToMetric(json)

        #expect(metricJson["name"] as? String == "cpu.usage")
        // Empty description / unit are omitted from the JSON.
        #expect(metricJson["description"] == nil)
        #expect(metricJson["unit"] == nil)

        let gauge = try JsonTestHelpers.cast(metricJson["gauge"], as: [String: Any].self)
        let dataPoints = try JsonTestHelpers.cast(gauge["dataPoints"], as: [Any].self)
        let dataPoint = try JsonTestHelpers.cast(dataPoints[0], as: [String: Any].self)
        #expect((dataPoint["asDouble"] as? Double) == 12.5)
        #expect(dataPoint["asInt"] == nil)
    }

    @Test("Encodes Histogram with string bucketCounts and explicit bounds")
    func encodesHistogram() throws {
        let point = HistogramPointData(
            startEpochNanos: startNanos,
            endEpochNanos: endNanos,
            attributes: [:],
            exemplars: [],
            sum: 27,
            count: 3,
            min: 1,
            max: 10,
            boundaries: [5.0],
            counts: [2, 1],
            hasMin: true,
            hasMax: true
        )

        let metric = MetricData(
            resource: resource,
            instrumentationScopeInfo: scope,
            name: "request.duration",
            description: "",
            unit: "ms",
            type: .Histogram,
            isMonotonic: false,
            data: HistogramData(aggregationTemporality: .cumulative, points: [point])
        )

        let request = JsonMetricsAdapter.toJsonRequest(metricData: [metric])
        let json = try JsonTestHelpers.encodeJson(request)
        let metricJson = try drillToMetric(json)

        let histogram = try JsonTestHelpers.cast(metricJson["histogram"], as: [String: Any].self)
        #expect(histogram["aggregationTemporality"] as? String == "AGGREGATION_TEMPORALITY_CUMULATIVE")

        let dataPoints = try JsonTestHelpers.cast(histogram["dataPoints"], as: [Any].self)
        let dataPoint = try JsonTestHelpers.cast(dataPoints[0], as: [String: Any].self)
        // count is uint64 → JSON string.
        #expect(dataPoint["count"] as? String == "3")
        // bucketCounts is repeated uint64 → array of JSON strings.
        let bucketCounts = try JsonTestHelpers.cast(dataPoint["bucketCounts"], as: [Any].self)
        #expect(bucketCounts.compactMap { $0 as? String } == ["2", "1"])
        let bounds = try JsonTestHelpers.cast(dataPoint["explicitBounds"], as: [Any].self)
        #expect(bounds.compactMap { $0 as? Double } == [5.0])
        #expect((dataPoint["sum"] as? Double) == 27.0)
        #expect((dataPoint["min"] as? Double) == 1.0)
        #expect((dataPoint["max"] as? Double) == 10.0)
    }

    @Test("Encodes exemplar traceId and spanId as lowercase hex")
    func encodesExemplar() throws {
        let traceIdHex = "0102030405060708090a0b0c0d0e0f10"
        let spanIdHex = "1112131415161718"
        let context = SpanContext.create(
            traceId: TraceId(fromHexString: traceIdHex),
            spanId: SpanId(fromHexString: spanIdHex),
            traceFlags: TraceFlags(),
            traceState: TraceState()
        )

        let exemplar = LongExemplarData(
            value: 7,
            epochNanos: endNanos,
            filteredAttributes: [:],
            spanContext: context
        )
        let point = LongPointData(
            startEpochNanos: startNanos,
            endEpochNanos: endNanos,
            attributes: [:],
            exemplars: [exemplar],
            value: 7
        )

        let metric = MetricData(
            resource: resource,
            instrumentationScopeInfo: scope,
            name: "x",
            description: "",
            unit: "",
            type: .LongGauge,
            isMonotonic: false,
            data: GaugeData(aggregationTemporality: .cumulative, points: [point])
        )

        let request = JsonMetricsAdapter.toJsonRequest(metricData: [metric])
        let json = try JsonTestHelpers.encodeJson(request)
        let metricJson = try drillToMetric(json)

        let gauge = try JsonTestHelpers.cast(metricJson["gauge"], as: [String: Any].self)
        let dataPoints = try JsonTestHelpers.cast(gauge["dataPoints"], as: [Any].self)
        let dataPoint = try JsonTestHelpers.cast(dataPoints[0], as: [String: Any].self)
        let exemplars = try JsonTestHelpers.cast(dataPoint["exemplars"], as: [Any].self)
        let exemplarJson = try JsonTestHelpers.cast(exemplars[0], as: [String: Any].self)

        #expect(exemplarJson["traceId"] as? String == traceIdHex)
        #expect(exemplarJson["spanId"] as? String == spanIdHex)
        #expect(exemplarJson["asInt"] as? String == "7")
        #expect(exemplarJson["timeUnixNano"] as? String == String(endNanos))
    }

    @Test("Drops metrics with no data points")
    func dropsEmptyMetrics() {
        let metric = MetricData(
            resource: resource,
            instrumentationScopeInfo: scope,
            name: "empty",
            description: "",
            unit: "",
            type: .LongSum,
            isMonotonic: false,
            data: SumData(aggregationTemporality: .cumulative, points: [])
        )

        let request = JsonMetricsAdapter.toJsonRequest(metricData: [metric])
        #expect(request.resourceMetrics.isEmpty)
    }

    @Test("Maps AggregationTemporality cases to the canonical proto-JSON enum strings")
    func mapsAggregationTemporality() {
        #expect(JsonMetricsAdapter.toJsonAggregationTemporality(.delta).rawValue == "AGGREGATION_TEMPORALITY_DELTA")
        #expect(JsonMetricsAdapter.toJsonAggregationTemporality(.cumulative).rawValue == "AGGREGATION_TEMPORALITY_CUMULATIVE")
    }

    // MARK: - Helpers

    private func drillToMetric(_ json: [String: Any]) throws -> [String: Any] {
        let resourceMetrics = try JsonTestHelpers.cast(json["resourceMetrics"], as: [Any].self)
        let resourceMetric = try JsonTestHelpers.cast(resourceMetrics[0], as: [String: Any].self)
        let scopeMetrics = try JsonTestHelpers.cast(resourceMetric["scopeMetrics"], as: [Any].self)
        let scopeMetric = try JsonTestHelpers.cast(scopeMetrics[0], as: [String: Any].self)
        let metrics = try JsonTestHelpers.cast(scopeMetric["metrics"], as: [Any].self)
        return try JsonTestHelpers.cast(metrics[0], as: [String: Any].self)
    }
}
