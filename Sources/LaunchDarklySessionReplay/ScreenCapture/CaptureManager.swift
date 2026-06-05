import Foundation
import Combine
import LaunchDarklyObservability
import UIKit

final class CaptureManager: EventSource {
    private let captureService: ImageCaptureServicing
    private let exportDiffManager: ExportDiffManager
    private let appLifecycleManager: AppLifecycleManaging
    @MainActor
    private var displayLink: CADisplayLink?
    private let eventQueue: EventQueue
    @MainActor
    private var lastFrameDispatchTime: DispatchTime?

    // Base (fast) cadence derived from the configured frame rate. The effective
    // cadence is adapted at runtime between `baseFrameInterval` and
    // `maxIdleFrameInterval` (see `effectiveFrameInterval`).
    private let baseFrameInterval: Double
    // Slowest cadence used while the screen is idle (a sequence of identical
    // frames). Capped so we never fully stop capturing.
    private let maxIdleFrameInterval: Double
    // Number of consecutive identical (non-exported) frames seen so far. Drives
    // the idle back-off once it passes `idleBackoffThreshold`.
    @MainActor
    private var idleFrameStreak: Int = 0
    // While `now < interactionDeadline` the cadence is pinned to the base (fast)
    // rate so user-driven changes are captured promptly.
    @MainActor
    private var interactionDeadline: DispatchTime?

    // Identical frames tolerated at the base rate before the cadence starts
    // backing off.
    private let idleBackoffThreshold = 3
    // Each idle step past the threshold multiplies the interval by this factor.
    private let idleBackoffMultiplier = 2.0
    // Duration of the fast-cadence window opened by each user interaction.
    private let interactionSpeedupWindow: Double = 1.0

    @MainActor
    private var isEventQueueAvailable: Bool = true
    @MainActor
    private var isCapturingInFlight: Bool = false
    private let sessionExporterId = ObjectIdentifier(SessionReplayExporter.self)
    private var cancellables = Set<AnyCancellable>()
    private let debugFrameWriter = false
    private let rawFrameWriter: RawFrameWriter?
    private let sessionIdProvider: @Sendable () -> String

    @MainActor
    var isEnabled: Bool = false {
        didSet {
            // here we shouldn't use guard because service can stop/start internally and isEnabled is flag what supposed to be in foreground
            if isEnabled {
                internalStart()
            } else {
                internalStop()
            }
        }
    }
    
    init(captureService: ImageCaptureServicing,
         compression: SessionReplayOptions.CompressionMethod,
         frameRate: Double,
         appLifecycleManager: AppLifecycleManaging,
         eventQueue: EventQueue,
         interactionSignal: AnyPublisher<Void, Never>? = nil,
         sessionIdProvider: @Sendable @escaping () -> String) {
        self.captureService = captureService
        let baseFrameInterval = frameRate > 0 ? 1.0 / frameRate : .infinity
        self.baseFrameInterval = baseFrameInterval
        self.maxIdleFrameInterval = baseFrameInterval.isFinite ? max(baseFrameInterval, 1.0) : .infinity
        self.exportDiffManager = ExportDiffManager(compression: compression, scale: 1.0)
        self.eventQueue = eventQueue
        self.appLifecycleManager = appLifecycleManager
        self.rawFrameWriter = debugFrameWriter ? (try? RawFrameWriter()) : nil
        self.sessionIdProvider = sessionIdProvider
        
        let sessionExporterId = self.sessionExporterId
        Task { @MainActor in
            let eventQueuePublisher = await eventQueue.publisher()
            eventQueuePublisher
                .filter { $0.id == sessionExporterId }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] event in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        switch event.status {
                        case .available:
                            self.isEventQueueAvailable = true
                        case .oveflowed:
                            self.isEventQueueAvailable = false
                        }
                    }
                }
                .store(in: &cancellables)
        }
        
        appLifecycleManager
            .publisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    switch event {
                    case .didBecomeActive:
                        self.internalStart()
                    case .willResignActive, .willTerminate:
                        self.internalStop()
                    case .didFinishLaunching, .willEnterForeground, .didEnterBackground:
                        break
                    }
                }
            }
            .store(in: &cancellables)

        interactionSignal?
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                MainActor.assumeIsolated {
                    self?.noteInteraction()
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func internalStart() {
        // isRunning belongs to public start()
        guard isEnabled, displayLink == nil else { return }
        
        let displayLink = CADisplayLink(target: self, selector: #selector(frameUpdate))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }
    
    @MainActor
    private func internalStop() {
        // to indicate stopping captureUIImage process in the middle
        captureService.interuptCapture()
        displayLink?.invalidate()
        displayLink = nil
        // An interrupted capture may never invoke its yield closure, so clear the
        // in-flight flag here to avoid wedging the loop on the next start.
        isCapturingInFlight = false
    }
    
    @MainActor
    @objc private func frameUpdate() {
        queueSnapshot()
    }
     
    @MainActor
    func queueSnapshot() {
        guard isEnabled, displayLink != nil, isEventQueueAvailable else {
            return
        }

        // Coalesce: a single capture (collect "before" → render → reconcile on
        // the next tick → encode) spans several runloop ticks, so the display
        // link can fire again while one is still in flight. Skip this tick
        // instead of starting an overlapping capture; the running capture clears
        // the flag when it yields (and `internalStop()` clears it if interrupted).
        guard !isCapturingInFlight else {
            return
        }

        let now = DispatchTime.now()
        if let lastFrameDispatchTime {
            let timeInBackground = Double(now.uptimeNanoseconds - lastFrameDispatchTime.uptimeNanoseconds) / Double(NSEC_PER_SEC)
            guard timeInBackground >= effectiveFrameInterval(now: now) else {
                return
            }
        }
        
        self.lastFrameDispatchTime = now
        self.isCapturingInFlight = true

        captureService.captureRawFrame { rawFrame in
            // The capture has produced (or dropped) a frame; release the gate so
            // the next display-link tick can start the following capture.
            await MainActor.run { self.isCapturingInFlight = false }

            guard let rawFrame else {
                // Capture was interrupted/failed: leave the cadence untouched.
                return
            }
            
            try? self.rawFrameWriter?.write(rawFrame: rawFrame)

            // A nil export means the frame was identical to the previous one
            // (content-based dedup). Feed that back into the cadence so a static
            // screen backs off, while any change snaps us back to the base rate.
            let exportFrame = self.exportDiffManager.exportFrame(from: rawFrame)
            await MainActor.run { self.recordCaptureResult(changed: exportFrame != nil) }

            guard let exportFrame else {
                // dropped frame
                return
            }
            
            await self.eventQueue.send(ImageItemPayload(exportFrame: exportFrame, sessionId: self.sessionIdProvider()))
        }
    }

    /// Current minimum interval between captures, adapted to recent activity.
    ///
    /// - Inside the post-interaction window the base (fast) rate is used.
    /// - Otherwise the interval grows geometrically once `idleFrameStreak`
    ///   exceeds `idleBackoffThreshold`, capped at `maxIdleFrameInterval`.
    @MainActor
    private func effectiveFrameInterval(now: DispatchTime) -> Double {
        if let interactionDeadline, now < interactionDeadline {
            return baseFrameInterval
        }
        guard idleFrameStreak > idleBackoffThreshold else {
            return baseFrameInterval
        }
        let steps = idleFrameStreak - idleBackoffThreshold
        let scaled = baseFrameInterval * pow(idleBackoffMultiplier, Double(steps))
        return min(scaled, maxIdleFrameInterval)
    }

    /// Records whether the most recent capture produced a change, driving the
    /// idle back-off. A change resets the streak (speed back up); an identical
    /// frame extends it (slow down).
    @MainActor
    private func recordCaptureResult(changed: Bool) {
        if changed {
            idleFrameStreak = 0
        } else {
            idleFrameStreak += 1
        }
    }

    /// Opens a fast-cadence window and resets the idle back-off so user-driven
    /// changes are captured promptly.
    @MainActor
    private func noteInteraction() {
        interactionDeadline = DispatchTime.now() + interactionSpeedupWindow
        idleFrameStreak = 0
    }
}
