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
    private var eventQueueAvailable: Bool = true
    private let sessionExporterId = ObjectIdentifier(SessionReplayExporter.self)
    private var cancellables = Set<AnyCancellable>()
    
    init(captureService: ScreenCaptureService,
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
                        self.eventQueueAvailable = true
                    case .oveflowed:
                        self.eventQueueAvailable = false
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
                    self?.start()
                case .willResignActive, .willTerminate:
                    self?.stop()
                case .didFinishLaunching, .willEnterForeground, .didEnterBackground:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    func start() {
        guard displayLink == nil else { return }
        
        let displayLink = CADisplayLink(target: self, selector: #selector(frameUpdate))
        displayLink.add(to: .main, forMode: .common)
        
        self.displayLink = displayLink
    }
    
    @objc private func frameUpdate() {
        queueSnapshot()
    }
    
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    func queueSnapshot() {
        guard let displayLink, eventQueueAvailable else {
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
