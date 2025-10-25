import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk


enum AppLifeCycleLogState: String, Sendable {
    static let eventName = "device.app.lifecycle"
    static let attributeName = "ios.app.state"
    
    // The app has become active. Associated with UIKit notification applicationDidBecomeActive.
    case active = "active"
    // The app is now in the background. This value is associated with UIKit notification applicationDidEnterBackground.
    case background = "background"
    // The app is now in the foreground. This value is associated with UIKit notification applicationWillEnterForeground.
    case foreground = "foreground"
    // The app is now inactive. Associated with UIKit notification applicationWillResignActive.
    case inactive = "inactive"
    // The app is about to terminate. Associated with UIKit notification applicationWillTerminate.
    case terminate = "terminate"
    
    init?(appLifecycleEvent: AppLifeCycleEvent) {
        switch appLifecycleEvent {
        case .didBecomeActive: self = .active
        case .didEnterBackground: self = .background
        case .willEnterForeground: self = .foreground
        case .willResignActive: self = .inactive
        case .willTerminate: self = .terminate
        case .didFinishLaunching: return nil
        }
    }
    
    var attributes: [String: AttributeValue] {
        [AppLifeCycleLogState.attributeName: .string(rawValue)]
    }
}

protocol AppLifecycleLogging: AutoInstrumentation {
    
}

final class AppLifecycleLogger: AppLifecycleLogging {
    private let appLifecycleManager: AppLifecycleManaging
    private let appLogBuilder: AppLogBuilder
    private let yield: (ReadableLogRecord) -> Void
    private var task: Task<Void, Never>?
    
    init(appLifecycleManager: AppLifecycleManaging, appLogBuilder: AppLogBuilder, yield: @escaping (ReadableLogRecord) -> Void) {
        self.appLifecycleManager = appLifecycleManager
        self.appLogBuilder = appLogBuilder
        self.yield = yield
    }
    
    func start() {
        guard task == nil else { return }
        
        task = Task(priority: .background) { [weak self] in
            guard let self else { return }
            
            for await event in await self.appLifecycleManager.events() {
                guard let state = AppLifeCycleLogState(appLifecycleEvent: event) else { continue }
                guard let log = self.appLogBuilder.buildLog(
                    message: AppLifeCycleLogState.eventName,
                    severity: .info,
                    attributes: state.attributes
                ) else { continue }
                
                self.yield(log)
            }
        }
    }
    
    func stop() {
        task?.cancel()
        task = nil
    }
}
