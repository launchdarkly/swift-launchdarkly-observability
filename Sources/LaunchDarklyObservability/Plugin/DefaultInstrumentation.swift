import Foundation
import OSLog
#if !LD_COCOAPODS
import LaunchDarklyOtel
#endif

/// The automatic instrumentation shipped with `LaunchDarklyObservability`: URLSession and
/// UIKit hooks, crash reporting, resource sampling and lifecycle tracking.
///
/// Each piece is gated by ``ObservabilityOptions/Instrumentation`` and installs itself only
/// when started, so a disabled feature leaves no hook behind.
final class DefaultInstrumentation: ObservabilityInstrumenting {
    private let autoInstrumentationSamplingInterval: TimeInterval = 5.0

    /// Resolved on first request and reused: ``makeCrashReporting`` and
    /// ``makeInstrumentation`` both need it (MetricKit reporting is also an instrument),
    /// and the order in which the service asks for them is not guaranteed.
    private var resolvedCrashReporting: CrashReporting?
    /// Created during installation but started later, alongside the other instruments.
    private var userInteractionManager: UserInteractionManager?

    func resolveAppLaunchSignal(appStartEndUptime: TimeInterval) -> AppLaunchSignal? {
        var signal: AppLaunchSignal?
        AppLaunchTracker(appStartEndUptime: appStartEndUptime) { signal = $0 }.start()
        return signal
    }

    func makeUserInteractionManager(runtime: ObservabilityRuntime) -> UserInteractionManaging? {
        let options = runtime.options
        // `instrumentation.userTaps` enables the tap-detection machinery (issuing tap events);
        // `analytics.taps` governs whether a detected tap is published as an OTel `click` span.
        // Capture still flows to Session Replay regardless of either flag.
        let userTapsEnabled = options.instrumentation.userTaps.isEnabled
        let publishTaps = options.analytics.taps.isEnabled
        let tracer = runtime.tracer

        let manager = UserInteractionManager(
            options: options,
            sessionManaging: runtime.session,
            // The active screen is read once at tap time and stamped onto the interaction, so the
            // OTel span here and the Session Replay click event report the identical screen.
            screenInfoProvider: { [weak runtime] in
                let screen = runtime?.currentScreen
                return (screen?.id, screen?.name)
            }
        ) { interaction in
            guard userTapsEnabled, publishTaps else { return }
            // Correlate the tap with the active screen (taxonomy §4.1 `event.screen_id`).
            interaction.startEndSpan(tracer: tracer, screenId: interaction.screenId, screenName: interaction.screenName)
        }
        userInteractionManager = manager
        return manager
    }

    func makeInstrumentation(runtime: ObservabilityRuntime) -> [Instrumentation] {
        let options = runtime.options
        var instruments = [Instrumentation]()

        if options.instrumentation.urlSession.isEnabled {
            instruments.append(
                NetworkInstrumentationManager(
                    options: options,
                    tracer: runtime.tracer,
                    session: runtime.session
                )
            )
        }

        // The touch-capture hook (UIWindow.sendEvent swizzle + hit-testing) is invasive, so it is
        // only installed when something needs it: tap detection here (gated by
        // `instrumentation.userTaps`) or Session Replay, which starts the same shared manager
        // itself. With both off, no swizzle or hit-testing is installed.
        if options.instrumentation.userTaps.isEnabled, let userInteractionManager {
            instruments.append(userInteractionManager)
        }

        if options.instrumentation.memory.isEnabled {
            instruments.append(
                MeasurementTask(metricsApi: runtime.metrics, samplingInterval: autoInstrumentationSamplingInterval) { api in
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
                MeasurementTask(metricsApi: runtime.metrics, samplingInterval: autoInstrumentationSamplingInterval) { api in
                    guard let value = CpuUtilizationManager.currentCPUUsage() else { return }
                    api.recordMetric(
                        metric: .init(name: SemanticConvention.systemCpuUtilization, value: value)
                    )
                }
            )
        }

        if options.instrumentation.memoryWarnings.isEnabled {
            instruments.append(
                MemoryPressureMonitor(options: options, runtime: runtime) { [weak runtime] log in
                    guard let runtime else { return }
                    await runtime.eventQueue.send(LogItem(log: log))
                }
            )
        }

        // Always track lifecycle so the Session Replay breadcrumb broadcast fires; the
        // `app_foreground`/`app_background` span is gated separately inside the pipeline.
        instruments.append(
            AppLifecycleTracker(appLifecycleManager: runtime.appLifecycle) { [weak runtime] signal in
                runtime?.recordAppLifecycleSignal(signal)
            }
        )

        // MetricKit reporting doubles as an instrument: it has to subscribe to the metric
        // manager to receive future diagnostic payloads, not just flush pending ones.
        if let metricKitReporter = crashReporting(runtime: runtime) as? Instrumentation {
            instruments.append(metricKitReporter)
        }

        return instruments
    }

    func makeScreenViewCapture(runtime: ObservabilityRuntime) -> ScreenViewCapturing? {
        ScreenViewManager { [weak runtime] screen in
            runtime?.recordScreenView(screen)
        }
    }

    func makeCrashReporting(runtime: ObservabilityRuntime) -> CrashReporting? {
        crashReporting(runtime: runtime)
    }

    private func crashReporting(runtime: ObservabilityRuntime) -> CrashReporting? {
        if let resolvedCrashReporting { return resolvedCrashReporting }

        let options = runtime.options
        let reporting: CrashReporting?
        switch options.crashReporting.source {
        case .KSCrash:
            reporting = try? KSCrashReportService(logsApi: runtime.logs, log: options.log)
            if reporting == nil {
                os_log("Crash reporting is disabled, the KSCrash report store is unavailable.", log: options.log, type: .error)
            }
        case .metricKit:
            #if os(iOS)
            if #available(iOS 15.0, *) {
                reporting = MetricKitCrashReporter(logsApi: runtime.logs, logger: options.log)
            } else {
                reporting = nil
                os_log("Crash reporting is disabled, MetricKit is not available on this platform version.", log: options.log, type: .info)
            }
            #else
            reporting = nil
            os_log("Crash reporting is disabled, MetricKit is not available on this platform.", log: options.log, type: .info)
            #endif
        case .none:
            reporting = nil
        }

        resolvedCrashReporting = reporting
        return reporting
    }
}
