import Combine
import Foundation
import OpenTelemetrySdk
import OSLog
import LaunchDarkly
#if !LD_COCOAPODS
    import Common
#endif

/// The OpenTelemetry pipeline: sampling, session stamping, batching and OTLP export for
/// logs, metrics and traces, plus the manual recording API and the analytics taxonomy
/// emitters (`track`, `screen_view`, `click`, `app_launch`, app lifecycle).
///
/// It installs no hooks into the host app on its own. Everything that swizzles, handles
/// signals or samples the process comes from an ``ObservabilityInstrumenting`` supplied to
/// ``install(instrumenting:)``; with none supplied the SDK only emits what the app records
/// explicitly, so it can coexist with another observability SDK.
public final class ObservabilityService: InternalObserve {
    var logClient: LogRecording { loggerClient }
    var customerLogClient: LogsApi { logger }
    var traceClient: TracesApi { _traceClient }
    private let logger: LogsApi
    private let meter: MetricsApi
    private let appTracer: TracesApi
    public let options: ObservabilityOptions
    public var context: ObservabilityContext?

    private let transportService: TransportService
    private let sessionManager: SessionManager
    public let eventQueue: EventQueue
    private let appLogBuilder: AppLogBuilder
    private let appLifecycleManager: AppLifecycleManager

    private let loggerClient: LogClient

    private let metricsClient: MetricsApi

    private let _traceClient: TraceClient
    let tracerDecorator: TracerDecorator

    /// Supplies the automatic instrumentation. `nil` when the SDK is used as a plain OTel
    /// pipeline, in which case nothing hooks into the host app.
    private var instrumenting: ObservabilityInstrumenting?
    private var instruments = [Instrumentation]()
    private var screenViewCapture: ScreenViewCapturing?
    private var crashReporting: CrashReporting?

    private let screenStack: ScreenStack
    /// Broadcasts each recorded screen view so Session Replay can emit `Navigate` events.
    private let screenViewSubject = PassthroughSubject<ScreenViewEvent, Never>()
    /// Broadcasts each `track` event so Session Replay can emit a `Track` event regardless of the
    /// entry path (`LDClient.track` or the manual `LDObserve.track` API).
    private let trackSubject = PassthroughSubject<TrackEvent, Never>()
    /// Broadcasts each identified context so Session Replay can identify the session regardless of
    /// the entry path (`LDClient.identify` or the manual `LDObserve.identify` API).
    private let identifySubject = PassthroughSubject<IdentifyEvent, Never>()
    /// Broadcasts each app-lifecycle signal so Session Replay can emit an `Open`/`Foreground`/
    /// `Background` breadcrumb, independent of the `analytics.appLifecycle` span flag.
    private let appLifecycleSubject = PassthroughSubject<AppLifecycleSignal, Never>()
    /// The one-shot process-launch signal, resolved by the instrumentation provider during
    /// ``install(instrumenting:)``. Handed to `ObservabilityContext` as an immutable setup value
    /// and emitted as the `app_launch` span during `start()`.
    private var appLaunchSignal: AppLaunchSignal?
    private var cancellables = Set<AnyCancellable>()

    let hookExporter: ObservabilityHookExporter

    private let startQueue = DispatchQueue(label: "com.launchdarkly.observability.service.start")
    private var task: Task<Void, Never>?

    private let contextKeysQueue = DispatchQueue(label: "com.launchdarkly.observability.service.contextKeys")
    private var _cachedContextKeyAttributes: [String: AttributeValue] = [:]
    private var cachedContextKeyAttributes: [String: AttributeValue] {
        get { contextKeysQueue.sync { _cachedContextKeyAttributes } }
        set { contextKeysQueue.sync { _cachedContextKeyAttributes = newValue } }
    }

    public init(
        options: ObservabilityOptions,
        mobileKey: String,
        sessionAttributes: [String: AttributeValue]
    ) throws {
        self.options = options

        // MARK: - Sampling
        let sampler = CustomSampler(sampler: ThreadSafeSampler.shared.sample(_:))
        guard let url = URL(string: options.backendUrl) else {
            throw InstrumentationError.invalidGraphQLUrl
        }
        let graphQLClient = GraphQLClient(endpoint: url, defaultHeaders: ["User-Agent": ObservabilitySDKInfo.userAgent()])

        Task {
            do {
                let samplingConfigClient = DefaultSamplingConfigClient(client: graphQLClient)
                let config = try await samplingConfigClient.getSamplingConfig(mobileKey: mobileKey)
                sampler.setConfig(config)
            } catch {
                os_log("%{public}@", log: options.log, type: .error, "getSamplingConfig failed with error: \(error)")
            }
        }

        // MARK: - AppLifecycleManager
        let appLifecycleManager = AppLifecycleManager()
        self.appLifecycleManager = appLifecycleManager

        let sessionManager = SessionManager(
            options: .init(
                timeout: options.sessionBackgroundTimeout,
                isDebug: options.isDebug,
                log: options.log),
            appLifecycleManager: appLifecycleManager
        )
        self.sessionManager = sessionManager

        // MARK: - EventQueue
        let eventQueue = EventQueue()
        self.eventQueue = eventQueue

        // MARK: - BatchWorker
        let batchWorker = BatchWorker(eventQueue: eventQueue, log: options.log)

        // MARK: - Transport Service
        let transportService = TransportService(eventQueue: eventQueue,
                                                batchWorker: batchWorker,
                                                sessionManager: sessionManager,
                                                appLifecycleManager: appLifecycleManager)
        self.transportService = transportService

        // MARK: - Logging
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(OTelPath.logsPath) else {
            throw InstrumentationError.invalidLogExporterUrl
        }

        let appLogBuilder = AppLogBuilder(options: options, sessionManager: sessionManager, sampler: sampler)
        let logClient = LogClient(eventQueue: eventQueue, appLogBuilder: appLogBuilder)
        self.loggerClient = logClient
        let appLogClient = AppLogClient(logLevel: options.logsApiLevel, logger: logClient)
        let logExporter = OtlpLogExporter(endpoint: url)
        Task {
            await batchWorker.addExporter(logExporter)
        }

        self.appLogBuilder = appLogBuilder
        self.logger = appLogClient

        // MARK: - Metrics
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(OTelPath.metricsPath) else {
            throw InstrumentationError.invalidMetricExporterUrl
        }

        let metricsEventExporter = OtlpMetricEventExporter(
            endpoint: url,
            config: .init(headers: options.customHeaders.map({ ($0.key, $0.value) }))
        )
        Task {
            await batchWorker.addExporter(metricsEventExporter)
        }
        let metricsScheduleExporter = OtlpMetricScheduleExporter(eventQueue: eventQueue)
        let reader = PeriodicMetricReaderBuilder(exporter: metricsScheduleExporter)
            .setInterval(timeInterval: 10.0)
            .build()

        let metricsClient = MetricsApiFactory.make(
            options: options,
            reader: reader
        )
        self.metricsClient = metricsClient

        let appMetricsClient = AppMetricsClient(
            options: options.metricsApi,
            metricsApiClient: metricsClient
        )
        self.meter = appMetricsClient

        // MARK: - Tracing
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(OTelPath.tracesPath) else {
            throw InstrumentationError.invalidTraceExporterUrl
        }

        // MARK: - OtlpTraceEventExporter
        let traceEventExporter = OtlpTraceEventExporter(
            endpoint: url,
            config: .init(headers: options.customHeaders.map({ ($0.key, $0.value) }))
        )
        Task {
            await batchWorker.addExporter(traceEventExporter)
        }

        let tracerDecorator = TracerDecorator(
            options: options,
            sessionManager: sessionManager,
            sampler: sampler,
            eventQueue: eventQueue
        )
        self.tracerDecorator = tracerDecorator
        let traceClient = TraceClient(
            options: options.tracesApi,
            tracer: tracerDecorator
        )
        self._traceClient = traceClient

        let appTraceClient = AppTraceClient(
            options: options.tracesApi,
            tracingApiClient: traceClient
        )
        self.appTracer = appTraceClient

        self.screenStack = ScreenStack()

        let context = ObservabilityContext(
            sdkKey: mobileKey,
            options: options,
            appLifecycleManager: appLifecycleManager,
            sessionManager: sessionManager,
            transportService: transportService,
            sessionAttributes: sessionAttributes,
            screenViews: screenViewSubject.eraseToAnyPublisher(),
            tracks: trackSubject.eraseToAnyPublisher(),
            identifies: identifySubject.eraseToAnyPublisher(),
            appLifecycleEvents: appLifecycleSubject.eraseToAnyPublisher()
        )
        self.context = context

        self.hookExporter = ObservabilityHookExporter(
            traceClient: traceClient,
            logClient: loggerClient,
            withSpans: true,
            withValue: true,
            options: options
        )
        // Route the afterTrack hook and identify context keys back into this service,
        // so it remains the single emitter of track spans.
        self.hookExporter.trackEmitter = self
    }

    /// Attaches the automatic instrumentation. Must be called before ``start()``, and before
    /// any other plugin reads ``context``: the touch-capture pipeline and the launch signal it
    /// provides are setup values that Session Replay reads once at construction.
    /// - Parameter appStartEndUptime: uptime marking the end of the startup window. Capture it
    ///   at the earliest SDK entry point so `start.duration_ms` measures app startup rather
    ///   than SDK initialization.
    public func install(instrumenting: ObservabilityInstrumenting, appStartEndUptime: TimeInterval) {
        self.instrumenting = instrumenting
        let launchSignal = instrumenting.resolveAppLaunchSignal(appStartEndUptime: appStartEndUptime)
        self.appLaunchSignal = launchSignal
        context?.attach(
            userInteractionManager: instrumenting.makeUserInteractionManager(runtime: self),
            appLaunchSignal: launchSignal
        )
    }
}

extension ObservabilityService {
    private func start() async throws {
        transportService.start()

        // A new session (e.g. after a background timeout) must start with a fresh navigation
        // history: otherwise the first `screen_view`/`Navigate` of the new session would resolve
        // `event.previous_screen` against the prior session, and a re-appearing first screen would
        // be deduped instead of emitting a fresh navigation.
        //
        // Only reset on an actual session *change*. `SessionManager.start` also publishes the
        // initial session asynchronously; resetting on it would clobber a first screen that was
        // recorded synchronously while starting screen capture below. Seed with the current
        // session id so the initial emission is ignored even if it arrives after this subscription.
        var lastSessionId = sessionManager.sessionInfo.id
        sessionManager.publisher()
            .sink { [weak self] info in
                guard let self, info.id != lastSessionId else { return }
                lastSessionId = info.id
                self.screenStack.reset()
                // Re-seed the new session with the screen the user is still viewing. UIKit won't
                // fire `viewDidAppear` for an already-visible controller, so without this the new
                // session would have no opening `screen_view` span or `Navigate` event.
                self.screenViewCapture?.captureCurrentScreen()
            }
            .store(in: &cancellables)

        guard let instrumenting else { return }

        instruments = instrumenting.makeInstrumentation(runtime: self)

        if options.instrumentation.screens.isEnabled {
            let capture = instrumenting.makeScreenViewCapture(runtime: self)
            screenViewCapture = capture
            capture?.start()
        }

        let crashReporting = instrumenting.makeCrashReporting(runtime: self)
        self.crashReporting = crashReporting
        crashReporting?.logPendingCrashReports()

        for instrument in instruments {
            instrument.start()
        }

        // Emit the `app_launch` span (and its `app.start` performance event) from the signal
        // resolved during `install`. Done here, after the tracer and cached context keys are
        // ready, so attributes are populated; gated by `analytics.appLaunch` inside the handler.
        if let appLaunchSignal {
            recordAppLaunchSignal(appLaunchSignal)
        }
    }
}

extension ObservabilityService {
    public func start(sessionId: String) {
        startSession(sessionId: sessionId, isCustomSession: true)
    }

    public func start() {
        startSession(sessionId: SecureIDGenerator.generateSecureID(), isCustomSession: false)
    }

    private func startSession(sessionId: String, isCustomSession: Bool) {
        startQueue.sync {
            guard task == nil else { return }
            task = Task { [weak self] in
                guard let self else { return }
                let id = SessionIdResolver.resolve(sessionId: sessionId, log: options.log)

                do {
                    self.context?.sessionManager.start(sessionId: id, isCustomSession: isCustomSession)
                    try await self.start()
                } catch {
                    os_log("%{public}@", log: options.log, type: .error, "Failure starting Observability Service: \(error)")
                }
            }
        }
    }
}

// MARK: - ObservabilityRuntime

extension ObservabilityService: ObservabilityRuntime {
    public var session: SessionManaging { sessionManager }
    public var appLifecycle: AppLifecycleManaging { appLifecycleManager }
    public var tracer: Tracer { tracerDecorator }
    /// The ungated meter: `options.metricsApi` only governs the customer-facing API.
    public var metrics: MetricsApi { metricsClient }
    /// The ungated log recorder: `options.logsApiLevel` only governs the customer-facing API.
    public var logs: LogRecording { loggerClient }

    public var currentScreen: (id: String?, name: String?) {
        (screenStack.currentId, screenStack.current)
    }

    public func buildLogRecord(
        message: String,
        severity: Severity,
        attributes: [String: AttributeValue],
        spanContext: SpanContext?
    ) -> ReadableLogRecord? {
        appLogBuilder.buildLog(message: message, severity: severity, attributes: attributes, spanContext: spanContext)
    }
}

extension ObservabilityService: Observe {
    public func recordLog(
        message: String,
        severity: Severity,
        attributes: [String: AttributeValue],
        spanContext: SpanContext?
    ) {
        logger.recordLog(message: message, severity: severity, attributes: attributes, spanContext: spanContext)
    }

    public func recordMetric(metric: Metric) {
        meter.recordMetric(metric: metric)
    }

    public func recordCount(metric: Metric) {
        meter.recordCount(metric: metric)
    }

    public func recordIncr(metric: Metric) {
        meter.recordIncr(metric: metric)
    }

    public func recordHistogram(metric: Metric) {
        meter.recordHistogram(metric: metric)
    }

    public func recordUpDownCounter(metric: Metric) {
        meter.recordUpDownCounter(metric: metric)
    }

    public func recordError(
        _ error: any Error,
        attributes: [String: AttributeValue]
    ) {
        appTracer.recordError(error, attributes: attributes)
    }

    public func startSpan(
        name: String,
        attributes: [String: AttributeValue]
    ) -> any Span {
        appTracer.startSpan(name: name, attributes: attributes)
    }

    public func track(key: String, properties: [String: Any]?, metricValue: Double?) {
        track(name: key,
              metricValue: metricValue,
              attributes: properties?.toOtelAttributes() ?? [:],
              contextKeyAttributes: nil)
    }

    public func identify(contextKeys: [String: String], canonicalKey: String, attributes: [String: Any]?) {
        hookExporter.sendAfterIdentify(
            contextKeys: contextKeys,
            canonicalKey: canonicalKey,
            attributes: attributes?.toOtelAttributes() ?? [:]
        )
    }

    public func trackScreenView(name: String, screenClass: String?, screenId: String?, category: String?, properties: [String: Any]?) {
        recordScreenView(
            ScreenView(
                name: name,
                screenClass: screenClass,
                screenId: screenId,
                category: category,
                attributes: properties?.toOtelAttributes() ?? [:]
            )
        )
    }

    /// Manually emit a `click` span, mirroring the automatic tap instrumentation. Use this
    /// to reproduce the taxonomy `click` event for interactions automatic capture can't observe.
    ///
    /// Gated by `analytics.taps` (the same flag as automatic click spans). When `screenId` is
    /// `nil`, the current tracked screen's id and name are used so the click correlates with the
    /// active `screen_view`; when an explicit `screenId` is supplied, `event.screen_name` is omitted
    /// (its name is unknown here) to avoid pairing one screen's id with another's name. Reserved
    /// `event.*` fields take precedence over caller `properties`, matching the `screen_view`/`track`
    /// precedence model.
    public func trackClick(id: String?, tag: String?, text: String?, screenId: String?, x: Int?, y: Int?, properties: [String: Any]?) {
        guard options.analytics.taps.isEnabled else { return }

        // Default to the current screen so the click correlates with the active `screen_view`. Only
        // pair the current screen's name when we actually defaulted to it; for a caller-supplied
        // `screenId` the matching name is unknown here, so omit `screen_name` rather than mismatch a
        // different screen's name with that id.
        let resolvedScreenName = screenId == nil ? screenStack.current : nil

        let spanAttributes = ClickAttributes.build(
            id: id,
            tag: tag,
            text: text,
            screenId: screenId ?? screenStack.currentId,
            screenName: resolvedScreenName,
            x: x,
            y: y,
            contextKeyAttributes: cachedContextKeyAttributes,
            properties: properties?.toOtelAttributes() ?? [:]
        )

        // Mirror the automatic tap span: a CLIENT-kind `click` span built via the decorator.
        let builder = tracerDecorator.spanBuilder(spanName: SemanticConvention.clickSpanName)
        builder.setSpanKind(spanKind: .client)
        for (key, value) in spanAttributes {
            builder.setAttribute(key: key, value: value)
        }
        builder.startSpan().end()
    }
}

extension ObservabilityService: TrackEmitting {
    /// Single emitter for `track` spans. Both the LD `afterTrack` hook and the
    /// manual `LDObserve.track` path funnel through here.
    func track(
        name: String,
        metricValue: Double?,
        attributes: [String: AttributeValue],
        contextKeyAttributes: [String: AttributeValue]?
    ) {
        // Broadcast so Session Replay can record a `Track` event for every track path, independent
        // of the trackEvents span flag below (mirrors the `Navigate` broadcast in recordScreenView).
        // Carries only user-supplied track data, matching the cross-platform bridge's payload.
        trackSubject.send(
            TrackEvent(
                name: name,
                metricValue: metricValue,
                attributes: attributes,
                timestamp: Date().timeIntervalSince1970
            )
        )

        guard options.analytics.trackEvents.isEnabled else { return }
        guard options.tracesApi.includeSpans else { return }

        // Apply in increasing precedence so event identity can never be clobbered: user-supplied
        // track data first, then context keys, then the reserved key/value attributes last.
        var spanAttributes: [String: AttributeValue] = [:]
        for (k, v) in attributes {
            spanAttributes[k] = v
        }
        // Fresh context keys from the hook take precedence; otherwise use the cached identify keys.
        for (k, v) in (contextKeyAttributes ?? cachedContextKeyAttributes) {
            spanAttributes[k] = v
        }
        spanAttributes["key"] = .string(name)
        if let metricValue {
            spanAttributes["value"] = .double(metricValue)
        }

        // `track` events are modeled as CONSUMER spans (an incoming domain event)
        // rather than INTERNAL. Built via the decorator so the span kind can be set.
        let builder = tracerDecorator.spanBuilder(spanName: SemanticConvention.trackSpanName)
        builder.setSpanKind(spanKind: .consumer)
        for (key, value) in spanAttributes {
            builder.setAttribute(key: key, value: value)
        }
        builder.startSpan().end()
    }

    /// Single funnel for screen changes. Both automatic capture and the manual
    /// `trackScreenView` API route through here so `previous_screen` resolution and
    /// context-key merging stay consistent.
    ///
    /// Screen detection itself is gated by ``ObservabilityOptions/Instrumentation/screens``
    /// (auto capture) or the explicit manual call. The `screen_view` span is gated
    /// separately by ``ObservabilityOptions/Analytics/screenViews``; the navigation
    /// broadcast (Session Replay `Navigate`) always fires once a screen is recorded.
    public func recordScreenView(_ screen: ScreenView) {
        // Resolve previous_screen against the shared stack before recording this one.
        // Identity is keyed on screenId (when present) so distinct screens sharing a
        // display name aren't collapsed into a re-appearance of one another.
        let previousScreen = screenStack.record(screen.name, id: screen.screenId)

        // Broadcast the navigation so Session Replay can emit a `Navigate` event,
        // mirroring the web SDK's per-path-change custom event. This is independent
        // of the `screen_view` span flag.
        screenViewSubject.send(
            ScreenViewEvent(
                name: screen.name,
                previousName: previousScreen,
                timestamp: screen.timestamp
            )
        )

        // Only the analytics span is gated by the screenViews flag.
        guard options.analytics.screenViews.isEnabled else { return }

        // Apply in increasing precedence so the screen-view taxonomy can never be clobbered: caller
        // properties first, then identify context keys, then the reserved `event.*` fields last
        // (matching the track path).
        var spanAttributes: [String: AttributeValue] = [:]
        for (k, v) in screen.attributes {
            spanAttributes[k] = v
        }
        for (k, v) in cachedContextKeyAttributes {
            spanAttributes[k] = v
        }
        spanAttributes[SemanticConvention.eventName] = .string(screen.name)
        if let screenClass = screen.screenClass {
            spanAttributes[SemanticConvention.eventScreenClass] = .string(screenClass)
        }
        if let screenId = screen.screenId {
            spanAttributes[SemanticConvention.eventScreenId] = .string(screenId)
        }
        if let previousScreen {
            spanAttributes[SemanticConvention.eventPreviousScreen] = .string(previousScreen)
        }
        if let category = screen.category {
            spanAttributes[SemanticConvention.eventCategory] = .string(category)
        }

        let span = appTracer.startSpan(name: SemanticConvention.screenViewSpanName, attributes: spanAttributes)
        span.end()
    }

    /// Single funnel for app-lifecycle signals. Broadcasts the signal so Session
    /// Replay can record an `Open`/`Foreground`/`Background` breadcrumb (always,
    /// mirroring the `Navigate`/`Track` broadcasts), then emits the taxonomy span
    /// only when gated on by `analytics.appLifecycle`.
    public func recordAppLifecycleSignal(_ signal: AppLifecycleSignal) {
        // Broadcast every transition (including the cold-launch foreground). Session Replay's
        // lifetime subscription captures the first foreground and forwards it to the exporter via
        // `setInitialForeground`, emitting it on the first wake-up batch; later transitions become
        // live breadcrumbs.
        appLifecycleSubject.send(signal)

        guard options.analytics.appLifecycle.isEnabled else { return }
        emitAppLifecycleSpan(signal)
    }

    /// Emits the app-lifecycle span (`app_foreground`, `app_background`).
    /// Mirrors the `track`/`screen_view` paths: identify context keys are applied
    /// first, then the taxonomy `event.*` fields last so they can never be clobbered.
    private func emitAppLifecycleSpan(_ signal: AppLifecycleSignal) {
        var spanAttributes: [String: AttributeValue] = [:]
        for (k, v) in cachedContextKeyAttributes {
            spanAttributes[k] = v
        }

        let spanName: String
        switch signal.kind {
        case .foreground:
            spanName = SemanticConvention.appForegroundSpanName
        case .background:
            spanName = SemanticConvention.appBackgroundSpanName
        }
        if let state = signal.lifecycleState {
            spanAttributes[SemanticConvention.eventLifecycleState] = .string(state)
        }

        let span = appTracer.startSpan(name: spanName, attributes: spanAttributes)
        span.end()
    }

    /// Emits the taxonomy `app_launch` span when gated on by `analytics.appLaunch`. The Session
    /// Replay `Launch` breadcrumb is delivered separately: the signal is handed to the exporter at
    /// construction (via `ObservabilityContext.appLaunchSignal`), not broadcast from here.
    public func recordAppLaunchSignal(_ signal: AppLaunchSignal) {
        guard options.analytics.appLaunch.isEnabled else { return }
        emitAppLaunchSpan(signal)
    }

    /// Emits the `app_launch` span. Context keys are applied first, then the taxonomy
    /// `event.*` fields, and finally the cold/warm startup dimension as an `app.start`
    /// span event (mirroring the analytics taxonomy `app_launch` shape).
    private func emitAppLaunchSpan(_ signal: AppLaunchSignal) {
        var spanAttributes: [String: AttributeValue] = [:]
        for (k, v) in cachedContextKeyAttributes {
            spanAttributes[k] = v
        }

        spanAttributes[SemanticConvention.eventLaunchType] = .string(signal.launchType.rawValue)
        if let version = signal.version {
            spanAttributes[SemanticConvention.eventVersion] = .string(version)
        }
        if let build = signal.build {
            spanAttributes[SemanticConvention.eventBuild] = .string(build)
        }
        if let previousVersion = signal.previousVersion {
            spanAttributes[SemanticConvention.eventPreviousVersion] = .string(previousVersion)
        }

        // The span is emitted at the end of `start()` (after async startup instrumentation), but it
        // represents the launch itself. Anchor it to the process-start instant carried by the
        // signal and end it at the launch-detection time, so analytics timestamps reflect the real
        // startup window and aren't skewed by SDK init work.
        let launchTime = Date(timeIntervalSince1970: signal.timestamp)
        // The startup-performance dimension (cold/warm `start.type` + `start.duration_ms`) is gated by
        // `instrumentation.launchTimes`. When it is off we also anchor the span at the launch-detection
        // time instead of back-dating it to process start, so the span window carries no startup
        // duration and `start.duration_ms` can't be recovered from it.
        let includeLaunchTime = options.instrumentation.launchTimes.isEnabled
        let spanStart = includeLaunchTime ? min(signal.processStartDate ?? launchTime, launchTime) : launchTime

        let span = appTracer.startSpan(name: SemanticConvention.appLaunchSpanName, attributes: spanAttributes, startTime: spanStart)
        // Taxonomy §4.6: cold/warm lives on the `app.start` span event (orthogonal to
        // `event.launch_type`), attached under `analytics.appLaunch` and gated by
        // `instrumentation.launchTimes`.
        if includeLaunchTime, let startType = signal.startType {
            var eventAttributes: [String: AttributeValue] = [
                SemanticConvention.startType: .string(startType.rawValue)
            ]
            if let durationMs = signal.startDurationMs {
                eventAttributes[SemanticConvention.startDurationMs] = .double(durationMs)
            }
            // Place the event at the launch-detection time so it falls within the span window.
            span.addEvent(name: SemanticConvention.appStartEventName, attributes: eventAttributes, timestamp: launchTime)
        }
        span.end(time: launchTime)
    }

    /// Single emitter for identifies. Both the LD `afterIdentify` hook and the manual
    /// `LDObserve.identify` path funnel through here (via the hook exporter, which owns the
    /// identify log).
    ///
    /// Caches the context keys so later `track`/`screen_view`/`click` spans are attributed to this
    /// context, then broadcasts so Session Replay can identify the session for every identify path
    /// (mirroring the `Track` broadcast in `track`). Caller-supplied identity attributes are
    /// deliberately not cached: they describe the identity, not every subsequent event.
    func recordIdentify(contextKeys: [String: String], canonicalKey: String,
                        attributes: [String: AttributeValue]) {
        var contextKeyAttributes = [String: AttributeValue]()
        for (k, v) in contextKeys {
            contextKeyAttributes[k] = .string(v)
        }
        cachedContextKeyAttributes = contextKeyAttributes

        identifySubject.send(
            IdentifyEvent(
                contextKeys: contextKeys,
                canonicalKey: canonicalKey,
                attributes: attributes,
                timestamp: Date().timeIntervalSince1970
            )
        )
    }
}
