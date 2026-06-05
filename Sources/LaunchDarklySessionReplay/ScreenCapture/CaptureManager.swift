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
    private let frameInterval: Double
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
         sessionIdProvider: @Sendable @escaping () -> String) {
        self.captureService = captureService
        self.frameInterval = frameRate > 0 ? 1.0 / frameRate : .infinity
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
            guard timeInBackground >= frameInterval else {
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
                // dropped frame
                return
            }
            
            try? self.rawFrameWriter?.write(rawFrame: rawFrame)

            guard let exportFrame = self.exportDiffManager.exportFrame(from: rawFrame) else {
                // dropped frame
                return
            }
            
            await self.eventQueue.send(ImageItemPayload(exportFrame: exportFrame, sessionId: self.sessionIdProvider()))
        }
    }
}
