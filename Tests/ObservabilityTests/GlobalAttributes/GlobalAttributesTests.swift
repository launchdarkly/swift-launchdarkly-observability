import Testing
import Foundation
import Combine
import OpenTelemetrySdk
@testable import LaunchDarklyOtel

@Suite(.serialized)
struct GlobalAttributesTests {

    // MARK: - Store

    @Test("setAttributes merges by key and removeAttributes drops keys")
    func mergeAndRemove() {
        let store = GlobalAttributesStore()

        store.set(["a": .string("1"), "b": .string("2")])
        store.set(["b": .string("two"), "c": .int(3)])
        #expect(store.snapshot == ["a": .string("1"), "b": .string("two"), "c": .int(3)])

        store.remove(["a", "missing"])
        #expect(store.snapshot == ["b": .string("two"), "c": .int(3)])
    }

    @Test("session keys managed by the SDK are never stored")
    func reservedKeysIgnored() {
        let store = GlobalAttributesStore()

        store.set([SemanticConvention.sessionId: .string("spoofed"), "tenant": .string("acme")])

        #expect(store.snapshot == ["tenant": .string("acme")])
    }

    @Test("globals only fill keys the signal doesn't already carry")
    func perCallWins() {
        let store = GlobalAttributesStore()
        store.set(["shared": .string("global"), "extra": .bool(true)])

        let merged = store.filling(["shared": .string("call")])

        #expect(merged == ["shared": .string("call"), "extra": .bool(true)])
    }

    @Test("attributes set before the plugin registers apply once it does")
    func setBeforeInit() async throws {
        let key = "test.preinit.\(UUID().uuidString)"
        defer { GlobalAttributesStore.shared.remove([key]) }

        // A fresh LDObserve is backed by the no-op client, as before plugin registration.
        LDObserve().setAttributes([key: .string("early")])

        let service = try ObservabilityService(
            options: ObservabilityOptions(otlpEndpoint: "http://127.0.0.1:1", backendUrl: "http://127.0.0.1:1"),
            mobileKey: "test-key",
            sessionAttributes: [:]
        )
        service.startSpan(name: "after-init", attributes: [:]).end()

        let span = try #require(await exportedSpans(service.eventQueue).first)
        #expect(span.attributes[key] == .string("early"))
    }

    // MARK: - Spans

    @Test("spans from the decorated tracer (the URLSession path) get globals, call attributes win")
    func decoratedTracerSpan() async throws {
        let store = GlobalAttributesStore()
        store.set(["tenant": .string("acme"), "http.method": .string("global")])
        let queue = EventQueue()
        let tracer = makeTracer(store: store, eventQueue: queue)

        // Mirrors NetworkInstrumentationManager: attributes are set on the builder before start.
        let builder = tracer.spanBuilder(spanName: "http.request")
        builder.setAttribute(key: "http.method", value: "GET")
        builder.startSpan().end()

        let span = try #require(await exportedSpans(queue).first)
        #expect(span.attributes["tenant"] == .string("acme"))
        #expect(span.attributes["http.method"] == .string("GET"))
    }

    @Test("manual spans and errors get globals")
    func manualSpanAndError() async throws {
        let store = GlobalAttributesStore()
        store.set(["tenant": .string("acme")])
        let queue = EventQueue()
        let tracer = makeTracer(store: store, eventQueue: queue)

        tracer.startSpan(name: "manual", attributes: ["own": .string("x")]).end()
        tracer.recordError(TestError(), attributes: [:])

        let spans = await exportedSpans(queue, count: 2)
        #expect(spans.count == 2)
        for span in spans {
            #expect(span.attributes["tenant"] == .string("acme"))
        }
        #expect(spans.first { $0.name == "manual" }?.attributes["own"] == .string("x"))
    }

    @Test("a span keeps the globals current at its start")
    func valuesCapturedAtSpanStart() async throws {
        let store = GlobalAttributesStore()
        store.set(["phase": .string("start")])
        let queue = EventQueue()
        let tracer = makeTracer(store: store, eventQueue: queue)

        let span = tracer.startSpan(name: "long", attributes: [:])
        store.set(["phase": .string("later"), "late": .bool(true)])
        span.end()

        let exported = try #require(await exportedSpans(queue).first)
        #expect(exported.attributes["phase"] == .string("start"))
        #expect(exported.attributes["late"] == nil)
    }

    @Test("globals can't replace the SDK-managed session id")
    func sessionIdNotOverridable() async throws {
        let store = GlobalAttributesStore()
        store.set([SemanticConvention.sessionId: .string("spoofed")])
        let queue = EventQueue()
        let tracer = makeTracer(store: store, eventQueue: queue)

        tracer.startSpan(name: "span", attributes: [:]).end()

        let span = try #require(await exportedSpans(queue).first)
        #expect(span.attributes[SemanticConvention.sessionId] == .string(StubSession.id))
    }

    // MARK: - Logs

    @Test("logs get globals, call attributes and session id win")
    func logRecord() throws {
        let store = GlobalAttributesStore()
        store.set(["tenant": .string("acme"), "shared": .string("global")])
        let builder = makeLogBuilder(store: store)

        let log = try #require(builder.buildLog(
            message: "hello",
            severity: .info,
            attributes: ["shared": .string("call")]
        ))

        #expect(log.attributes["tenant"] == .string("acme"))
        #expect(log.attributes["shared"] == .string("call"))
        #expect(log.attributes[SemanticConvention.sessionId] == .string(StubSession.id))
    }

    // MARK: - Metrics

    @Test("metric data points get globals, metric attributes win")
    func metricDataPoints() async throws {
        let store = GlobalAttributesStore()
        store.set(["tenant": .string("acme"), "shared": .string("global")])
        let queue = EventQueue()
        let reader = PeriodicMetricReaderBuilder(exporter: OtlpMetricScheduleExporter(eventQueue: queue))
            .setInterval(timeInterval: 3600)
            .build()
        let metrics = try #require(
            MetricsApiFactory.make(options: ObservabilityOptions(), reader: reader, globalAttributes: store) as? MetricsClient
        )

        metrics.recordCount(metric: Metric(name: "test.count", value: 1, attributes: ["shared": .string("call")]))
        _ = metrics.flush()

        let items: [MetricItem] = await exportedItems(queue)
        let point = try #require(items.first { $0.metricData.name == "test.count" }?.metricData.data.points.first)
        #expect(point.attributes["tenant"] == .string("acme"))
        #expect(point.attributes["shared"] == .string("call"))
    }
}

// MARK: - Helpers

private struct TestError: Error {}

private final class StubSession: SessionManaging {
    static let id = "test-session-id"
    let sessionInfo = SessionInfo(id: StubSession.id, startTime: Date())
    func publisher() -> AnyPublisher<SessionInfo, Never> { Empty().eraseToAnyPublisher() }
    func start(sessionId: String, isCustomSession: Bool) {}
}

private func makeTracer(store: GlobalAttributesStore, eventQueue: EventQueue) -> TracerDecorator {
    TracerDecorator(
        options: ObservabilityOptions(),
        sessionManager: StubSession(),
        sampler: FakeExportSampler(),
        eventQueue: eventQueue,
        globalAttributes: store
    )
}

private func makeLogBuilder(store: GlobalAttributesStore) -> AppLogBuilder {
    AppLogBuilder(
        options: ObservabilityOptions(),
        sessionManager: StubSession(),
        sampler: FakeExportSampler(),
        globalAttributes: store
    )
}

/// Waits for the asynchronous hand-off from the processors to the queue.
private func exportedItems<T>(_ queue: EventQueue, count: Int = 1, timeout: TimeInterval = 3) async -> [T] {
    let deadline = Date().addingTimeInterval(timeout)
    var items = [T]()
    while Date() < deadline {
        items = (await queue.earliest(cost: .max, limit: .max, except: [])?.items ?? [])
            .compactMap { $0.payload as? T }
        if items.count >= count { break }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return items
}

private func exportedSpans(_ queue: EventQueue, count: Int = 1) async -> [SpanData] {
    let items: [SpanItem] = await exportedItems(queue, count: count)
    return items.map(\.spanData)
}
