import Foundation
import Combine
import LaunchDarklyObservability
import UIKit

final class SnapshotTaker: EventSource {
    private let captureService: ScreenCaptureService
    private let appLifecycleManager: AppLifecycleManaging
    private var displayLink: CADisplayLink?
    private let eventQueue: EventQueue
    private var lastFrameDispatchTime: DispatchTime?
    private let frameInterval = 1.0
    private var isEventQueueAvailable: Bool = true
    private let sessionExporterId = ObjectIdentifier(SessionReplayExporter.self)
    private var cancellables = Set<AnyCancellable>()
    
    @MainActor
    private var isEnabled: Bool {
        
    }
    
    init(isEnabled: Bool,
         captureService: ScreenCaptureService,
         appLifecycleManager: AppLifecycleManaging,
         eventQueue: EventQueue) {
        self.captureService = captureService
        self.eventQueue = eventQueue
        self.appLifecycleManager = appLifecycleManager
        
        let sessionExporterId = self.sessionExporterId
        Task { @MainActor in
            let eventQueuePublisher = await eventQueue.publisher()
            eventQueuePublisher
                .filter { $0.id == sessionExporterId }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] event in
                    guard let self else { return }
                    switch event.status {
                    case .available:
                        self.isEventQueueAvailable = true
                    case .oveflowed:
                        self.isEventQueueAvailable = false
                    }
                }
                .store(in: &cancellables)
        }
        
        appLifecycleManager
            .publisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .didBecomeActive:
                    self?.internalStart()
                case .willResignActive, .willTerminate:
                    self?.internalStop()
                case .didFinishLaunching, .willEnterForeground, .didEnterBackground:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    func start() {
        isEnabled = true
        internalStart()
    }
    
    @MainActor
    func stop() {
        internalStop()

        guard isEnabled else { return }
        isEnabled = false
    }
    
    func shouldRun() -> Bool {
        isEnabled
    }
    
    func internalStart() {
        // isRunning belongs to public start()
        guard isEnabled, displayLink == nil else { return }
        
        let displayLink = CADisplayLink(target: self, selector: #selector(frameUpdate))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }
    
    func internalStop() {
        captureService.shouldCapture = false
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
        
        captureService.captureUIImage { capturedImage in
            guard let capturedImage else {
                // dropped frame
                return
            }
            
            guard let exportImage = capturedImage.image.exportImage(format: .jpeg(quality: 0.3),
                                                                    originalSize: capturedImage.renderSize,
                                                                    scale: capturedImage.scale,
                                                                    timestamp: capturedImage.timestamp,
                                                                    orientation: capturedImage.orientation) else {
                return
            }
            
            await self.eventQueue.send(ImageItemPayload(exportImage: exportImage))
        }
    }
}
