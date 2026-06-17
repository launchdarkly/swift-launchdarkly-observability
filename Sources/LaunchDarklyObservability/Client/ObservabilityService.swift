import Combine
import Foundation
import OpenTelemetrySdk
import OSLog
import LaunchDarkly
#if !LD_COCOAPODS
    import Common
#endif

final class ObservabilityService: InternalObserve {
    var logClient: InternalLogsApi { loggerClient }
    var customerLogClient: LogsApi { logger }
    var traceClient: TracesApi { _traceClient }
    private let logger: LogsApi
    private let meter: MetricsApi
    private let tracer: TracesApi
    private let options: ObservabilityOptions
    public var context: ObservabilityContext?
    
    private let autoInstrumentationSamplingInterval: TimeInterval = 5.0
    /// Uptime captured at the earliest SDK entry point. Swift evaluates stored-property defaults
    /// during `init`, before any of the service's setup work (transport, crash-report flushing,
    /// instrument wiring) runs, so using this as the end of the cold/warm startup window keeps the
    /// `app.start` `start.duration_ms` from being inflated by the SDK's own initialization time.
    private let appStartEndUptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    private let transportService: TransportService
    private let sessionManager: SessionManager
    private let eventQueue: EventQueue
    private let appLogBuilder: AppLogBuilder
    private let appLifecycleManager: AppLifecycleManager
    
    private let loggerClient: LogClient
    
    private let metricsClient: MetricsApi
    
    private let _traceClient: TraceClient
    let tracerDecorator: TracerDecorator
    
    private var instruments = [AutoInstrumentation]()
    
    private let userInteractionManager: UserInteractionManager
    private let screenStack: ScreenStack
    private var screenViewManager: ScreenViewManager?
    /// Broadcasts each recorded screen view so Session Replay can emit `Navigate` events.
    private let screenViewSubject = PassthroughSubject<ScreenViewEvent, Never>()
    /// Broadcasts each `track` event so Session Replay can emit a `Track` event regardless of the
    /// entry path (`LDClient.track` or the manual `LDObserve.track` API).
    private let trackSubject = PassthroughSubject<TrackEvent, Never>()
    /// Broadcasts each app-lifecycle signal so Session Replay can emit an `Open`/`Foreground`/
    /// `Background` breadcrumb, independent of the `analytics.appLifecycle` span flag.
    private let appLifecycleSubject = PassthroughSubject<AppLifecycleSignal, Never>()
    /// The one-shot process-launch signal, resolved at the earliest point in `init` (persisting the
    /// app version exactly once). Handed to `ObservabilityContext` as an immutable setup value and
    /// emitted as the `app_launch` span during `start()`.
    private let appLaunchSignal: AppLaunchSignal?
    private var crashReporting: CrashReporting?
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
    
    init(
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
        self.tracer = appTraceClient
        
        // `instrumentation.userTaps` enables the tap-detection machinery (issuing tap
        // events); `analytics.taps` governs whether a detected tap is published as an OTel
        // `click` span. Capture still flows to Session Replay regardless of either flag.
        let userTapsEnabled = options.instrumentation.userTaps.isEnabled
        let publishTaps = options.analytics.taps.isEnabled
        // Created as a local so the tap closure can read the current screen id without
        // capturing `self` (which isn't fully initialized yet at this point in `init`).
        let screenStack = ScreenStack()
        self.screenStack = screenStack
        let userInteractionManager = UserInteractionManager(options: options, sessionManaging: sessionManager) { interaction in
            guard userTapsEnabled else { return }
            guard publishTaps else { return }
            // Correlate the tap with the active screen (taxonomy §4.1 `event.screen_id`).
            interaction.startEndSpan(tracer: tracerDecorator, screenId: screenStack.currentId, screenName: screenStack.current)
        }
        self.userInteractionManager = userInteractionManager

        // Resolve the one-shot launch signal at the earliest point so it can be handed to the
        // context as an immutable setup value (Session Replay injects it into the exporter at
        // construction). Resolved synchronously here via a local closure — no `self` capture and
        // no cross-thread mailbox — and persists the app version exactly once. The `app_launch`
        // span is emitted later in `start()` once the tracer and cached context keys are ready.
        var resolvedLaunchSignal: AppLaunchSignal?
        AppLaunchTracker(appStartEndUptime: appStartEndUptime) { resolvedLaunchSignal = $0 }.start()
        self.appLaunchSignal = resolvedLaunchSignal
        
        let context = ObservabilityContext(
            sdkKey: mobileKey,
            options: options,
            appLifecycleManager: appLifecycleManager,
            sessionManager: sessionManager,
            transportService: transportService,
            userInteractionManager: userInteractionManager,
            sessionAttributes: sessionAttributes,
            screenViews: screenViewSubject.eraseToAnyPublisher(),
            tracks: trackSubject.eraseToAnyPublisher(),
            appLifecycleEvents: appLifecycleSubject.eraseToAnyPublisher(),
            appLaunchSignal: appLaunchSignal
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

        // Automatic screen_view capture routes appearing screens back through the
        // same single emitter used by the manual `trackScreenView` API.
        self.screenViewManager = ScreenViewManager { [weak self] screen in
            self?.emitScreenView(screen)
        }
    }
}

extension ObservabilityService {
    private func start() async throws {
        let options = self.options
        
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
                self.screenViewManager?.captureCurrentScreen()
            }
            .store(in: &cancellables)
        
        // MARK: - Network
        if options.instrumentation.urlSession.isEnabled {
            instruments.append(
                NetworkInstrumentationManager(
                    options: options,
                    tracer: tracerDecorator,
                    session: sessionManager
                )
            )
        }
        
        // The touch-capture hook (UIWindow.sendEvent swizzle + hit-testing) is invasive, so it is
        // only installed when something needs it: tap detection here (gated by
        // `instrumentation.userTaps`) or Session Replay, which starts the same shared manager
        // itself. With both off, no swizzle or hit-testing is installed.
        if options.instrumentation.userTaps.isEnabled {
            userInteractionManager.start()
        }

        if options.instrumentation.screens.isEnabled {
            screenViewManager?.start()
        }
        
        if options.instrumentation.memory.isEnabled {
            instruments.append(
                MeasurementTask(metricsApi: metricsClient, samplingInterval: autoInstrumentationSamplingInterval) { api in
                    guard let report = MemoryUseManager.memoryReport(log: options.log) else { return }
                    api.recordMetric(
                        metric: .init(name: SemanticConvention.systemMemoryAppUsageBytes, value: Double(report.appMemoryBytes))
                    )
                    api.recordMetric(
                        metric: .init(name: SemanticConvention.systemMemoryAppTotalBytes, value: Double(report.systemTotalBytes))
                    )
                }
            )
        }
        
        if options.instrumentation.cpu.isEnabled {
            instruments.append(
                MeasurementTask(metricsApi: metricsClient, samplingInterval: autoInstrumentationSamplingInterval) { api in
                    guard let value = CpuUtilizationManager.currentCPUUsage() else { return }
                    api.recordMetric(
                        metric: .init(name: SemanticConvention.systemCpuUtilization, value: value)
                    )
                }
            )
        }
        
        if options.instrumentation.memoryWarnings.isEnabled {
            let memoryWarningMonitor = MemoryPressureMonitor(options: options, appLogBuilder: appLogBuilder) { [weak self] log in
                guard let self else { return }
                await eventQueue.send(LogItem(log: log))
            }
            instruments.append(memoryWarningMonitor)
        }
        
        // Always track lifecycle so the Session Replay breadcrumb broadcast fires; the
        // `app_foreground`/`app_background` span is gated separately below.
        let appLifecycleTracker = AppLifecycleTracker(appLifecycleManager: appLifecycleManager) { [weak self] signal in
            self?.handleAppLifecycleSignal(signal)
        }
        instruments.append(appLifecycleTracker)

        let crashReporting: CrashReporting
        if options.crashReporting.source == .KSCrash {
            crashReporting = try KSCrashReportService(logsApi: logClient, log: options.log)
            crashReporting.logPendingCrashReports()
        } else if options.crashReporting.source == .metricKit {
            #if os(iOS)
            if #available(iOS 15.0, *) {
                let reporter = MetricKitCrashReporter(logsApi: logClient, logger: options.log)
                crashReporting = reporter
                crashReporting.logPendingCrashReports()
                instruments.append(reporter)
            } else {
                crashReporting = NoOpCrashReport()
                os_log("Crash reporting is disabled, MetricKit is not available on this platform version.", log: options.log, type: .info)
            }
            #else
            crashReporting = NoOpCrashReport()
            os_log("Crash reporting is disabled, MetricKit is not available on this platform.", log: options.log, type: .info)
            #endif
        } else {
            crashReporting = NoOpCrashReport()
        }
        self.crashReporting = crashReporting

        for instrument in instruments {
            instrument.start()
        }

        // Emit the `app_launch` span (and its `app.start` performance event) from the signal resolved
        // at the earliest point in `init`. Done here, after the tracer and cached context keys are
        // ready, so attributes are populated; gated by `analytics.appLaunch` inside the handler.
        if let appLaunchSignal {
            handleAppLaunchSignal(appLaunchSignal)
        }
    }
}

extension ObservabilityService {
    func start(sessionId: String) {
        startSession(sessionId: sessionId, isCustomSession: true)
    }

    func start() {
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

extension ObservabilityService: Observe {
    func recordLog(
        message: String,
        severity: Severity,
        attributes: [String: AttributeValue],
        spanContext: SpanContext?
    ) {
        logger.recordLog(message: message, severity: severity, attributes: attributes, spanContext: spanContext)
    }

    func recordMetric(metric: Metric) {
        meter.recordMetric(metric: metric)
    }

    func recordCount(metric: Metric) {
        meter.recordCount(metric: metric)
    }

    func recordIncr(metric: Metric) {
        meter.recordIncr(metric: metric)
    }

    func recordHistogram(metric: Metric) {
        meter.recordHistogram(metric: metric)
    }

    func recordUpDownCounter(metric: Metric) {
        meter.recordUpDownCounter(metric: metric)
    }

    func recordError(
        _ error: any Error,
        attributes: [String: AttributeValue]
    ) {
        tracer.recordError(error, attributes: attributes)
    }

    func startSpan(
        name: String,
        attributes: [String: AttributeValue]
    ) -> any Span {
        tracer.startSpan(name: name, attributes: attributes)
    }

    func track(key: String, properties: [String: Any]?, metricValue: Double?) {
        track(name: key,
              metricValue: metricValue,
              attributes: properties?.toOtelAttributes() ?? [:],
              contextKeyAttributes: nil)
    }

    func trackScreenView(name: String, screenClass: String?, screenId: String?, category: String?, properties: [String: Any]?) {
        emitScreenView(
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
    /// `nil`, the current tracked screen id is used so the click correlates with the active
    /// `screen_view`. Reserved `event.*` fields take precedence over caller `properties`,
    /// matching the `screen_view`/`track` precedence model.
    func trackClick(id: String?, tag: String?, text: String?, screenId: String?, x: Int?, y: Int?, properties: [String: Any]?) {
        guard options.analytics.taps.isEnabled else { return }

        let spanAttributes = ClickAttributes.build(
            id: id,
            tag: tag,
            text: text,
            // Default to the current screen so the click correlates with the active `screen_view`.
            screenId: screenId ?? screenStack.currentId,
            screenName: screenStack.current,
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
        // of the trackEvents span flag below (mirrors the `Navigate` broadcast in emitScreenView).
        // Carries only user-supplied track data, matching the previous SessionReplayHook payload.
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

    /// Single funnel for screen changes. Both the automatic
    /// `ViewControllerScreenSource` capture and the manual `trackScreenView` API
    /// route through here so `previous_screen` resolution and context-key
    /// merging stay consistent.
    ///
    /// Screen detection itself is gated by ``ObservabilityOptions/Instrumentation/screens``
    /// (auto capture) or the explicit manual call. The `screen_view` span is gated
    /// separately by ``ObservabilityOptions/Analytics/screenViews``; the navigation
    /// broadcast (Session Replay `Navigate`) always fires once a screen is recorded.
    func emitScreenView(_ screen: ScreenView) {
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

        let span = tracer.startSpan(name: SemanticConvention.screenViewSpanName, attributes: spanAttributes)
        span.end()
    }

    /// Single funnel for app-lifecycle signals. Broadcasts the signal so Session
    /// Replay can record an `Open`/`Foreground`/`Background` breadcrumb (always,
    /// mirroring the `Navigate`/`Track` broadcasts), then emits the taxonomy span
    /// only when gated on by `analytics.appLifecycle`.
    func handleAppLifecycleSignal(_ signal: AppLifecycleSignal) {
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

        let span = tracer.startSpan(name: spanName, attributes: spanAttributes)
        span.end()
    }

    /// Emits the taxonomy `app_launch` span when gated on by `analytics.appLaunch`. The Session
    /// Replay `Launch` breadcrumb is delivered separately: the signal is handed to the exporter at
    /// construction (via `ObservabilityContext.appLaunchSignal`), not broadcast from here.
    func handleAppLaunchSignal(_ signal: AppLaunchSignal) {
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
        // represents the launch itself. Anchor it to the process-start instant captured at dylib
        // load (`AppStartTime`) and end it at the launch-detection time carried by the signal, so
        // analytics timestamps reflect the real startup window and aren't skewed by SDK init work.
        let launchTime = Date(timeIntervalSince1970: signal.timestamp)
        // The startup-performance dimension (cold/warm `start.type` + `start.duration_ms`) is gated by
        // `instrumentation.launchTimes`. When it is off we also anchor the span at the launch-detection
        // time instead of back-dating it to process start, so the span window carries no startup
        // duration and `start.duration_ms` can't be recovered from it.
        let includeLaunchTime = options.instrumentation.launchTimes.isEnabled
        let spanStart = includeLaunchTime ? min(AppStartTime.stats.startDate, launchTime) : launchTime

        let span = tracer.startSpan(name: SemanticConvention.appLaunchSpanName, attributes: spanAttributes, startTime: spanStart)
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

    func updateCachedContextKeys(_ contextKeys: [String: String]) {
        var attributes = [String: AttributeValue]()
        for (k, v) in contextKeys {
            attributes[k] = .string(v)
        }
        cachedContextKeyAttributes = attributes
    }
}
