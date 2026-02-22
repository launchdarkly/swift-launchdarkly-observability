import Foundation
import Combine
import LaunchDarklyObservability
import UIKit

final class CaptureManager: EventSource {
    private let captureService: ImageCaptureService
    private let exportDiffManager: ExportDiffManager
    private let appLifecycleManager: AppLifecycleManaging
    @MainActor
    private var displayLink: CADisplayLink?
    private let eventQueue: EventQueue
    @MainActor
    private var lastFrameDispatchTime: DispatchTime?
    private let frameInterval = 1.0
    @MainActor
    private var isEventQueueAvailable: Bool = true
    private let sessionExporterId = ObjectIdentifier(SessionReplayExporter.self)
    private var cancellables = Set<AnyCancellable>()
    private let debugFrameWriter = false
    private let rawFrameWriter: RawFrameWriter?
    
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
    
    init(captureService: ImageCaptureService,
         compression: SessionReplayOptions.CompressionMethod,
         appLifecycleManager: AppLifecycleManaging,
         eventQueue: EventQueue) {
        self.captureService = captureService
        self.exportDiffManager = ExportDiffManager(compression: compression, scale: 1.0)
        self.eventQueue = eventQueue
        self.appLifecycleManager = appLifecycleManager
        self.rawFrameWriter = debugFrameWriter ? (try? RawFrameWriter()) : nil
        
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
    }
    
    @MainActor
    @objc private func frameUpdate() {
        queueSnapshot()
    }
     
    @MainActor
    func queueSnapshot() {
        guard isEnabled, let displayLink, isEventQueueAvailable else {
            return
        }
        
        let now = DispatchTime.now()
        if let lastFrameDispatchTime {
            let timeInBackground = Double(DispatchTime.now().uptimeNanoseconds - lastFrameDispatchTime.uptimeNanoseconds) / Double(NSEC_PER_SEC)
            guard timeInBackground >= frameInterval else {
                return
            }
        }
        
        let lastFrameDispatchTime = DispatchTime.now()
        self.lastFrameDispatchTime = lastFrameDispatchTime
        
        captureService.captureRawFrame { rawFrame in
            guard let rawFrame else {
                // dropped frame
                return
            }

            try? self.rawFrameWriter?.write(rawFrame: rawFrame)

            guard let exportFrame = self.exportDiffManager.exportFrame(from: rawFrame) else {
                // dropped frame
                return
            }
            
            await self.eventQueue.send(ImageItemPayload(exportFrame: exportFrame))
        }
    }
}
