import Foundation
import Combine
import LaunchDarklyObservability
import UIKit

final class CaptureManager: EventSource {
    private let captureService: ImageCaptureService
    private let tileDiffManager: TileDiffManager
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
         transferMethod: SessionReplayOptions.TransferMethod,
         appLifecycleManager: AppLifecycleManaging,
         eventQueue: EventQueue) {
        self.captureService = captureService
        self.tileDiffManager = TileDiffManager(transferMethod: transferMethod, scale: 1.0)
        self.eventQueue = eventQueue
        self.appLifecycleManager = appLifecycleManager
        
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

            guard let capturedFrame = self.tileDiffManager.computeDiffCapture(frame: rawFrame) else {
                // dropped frame
                return
            }
            
            guard let exportFrame = self.exportFrame(from: capturedFrame) else {
                // dropped frame
                return
            }
            
            await self.eventQueue.send(ImageItemPayload(exportFrame: exportFrame))
        }
    }
    
    private func exportFrame(from capturedFrame: TiledFrame) -> ExportFrame? {
        let format = ExportFormat.jpeg(quality: 0.3)
        var exportedFrames = [ExportFrame.ExportImage]()
        for tile in capturedFrame.tiles {
            guard let exportedFrame = tile.image.asExportedImage(format: format, rect: tile.rect) else {
                return nil
            }
            exportedFrames.append(exportedFrame)
        }
        guard !exportedFrames.isEmpty else { return nil }
        
        return ExportFrame(images: exportedFrames,
                           originalSize: capturedFrame.originalSize,
                           scale: capturedFrame.scale,
                           format: format,
                           timestamp: capturedFrame.timestamp,
                           orientation: capturedFrame.orientation,
                           isKeyframe: capturedFrame.isKeyframe)
    }
}
