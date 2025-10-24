import Foundation
import Observability

typealias ExportImageYield = @Sendable (ExportImage) async -> Void

final class SnapshotTaker: EventSource {
    private let captureService: ScreenCaptureService
    private let yield: ExportImageYield
    private let appLifecycleManager: AppLifecycleManaging
    private var timer: Timer?
    
    init(captureService: ScreenCaptureService,
         appLifecycleManager: AppLifecycleManaging,
         yield: @escaping ExportImageYield) {
        self.captureService = captureService
        self.yield = yield
        self.appLifecycleManager = appLifecycleManager
        
        Task(priority: .background) { [weak self, weak appLifecycleManager] in
            guard let self, let appLifecycleManager else { return }

            let eventsStream = await appLifecycleManager.events()
            for await event in eventsStream {
                switch event {
                case .didBecomeActive:
                    await MainActor.run { [weak self] in
                        self?.start()
                    }
                case .willResignActive, .willTerminate:
                    await MainActor.run { [weak self] in
                        self?.stop()
                    }
                case .didFinishLaunching, .willEnterForeground, .didEnterBackground:
                    () // NO-OP
                }
            }
        }
    }
    
    func start() {
        guard timer == nil else { return }
        
        let timer = Timer(timeInterval: 1.0, target: self, selector: #selector(queueSnapshot), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .default)
        self.timer = timer
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc func queueSnapshot() {
        guard let timer,
              let capturedImage = captureService.captureUIImage() else {
            return
        }
        
        Task {
            guard let exportImage = capturedImage.image.exportImage(format: .jpeg(quality: 0.3),
                                                                    originalSize: capturedImage.renderSize,
                                                                    scale: capturedImage.scale,
                                                                    timestamp: capturedImage.timestamp) else {
                return
            }
            
            await yield(exportImage)
        }
    }
}
