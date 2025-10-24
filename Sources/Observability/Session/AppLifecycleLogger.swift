import Foundation

enum AppLifeCycleLogState: String, Sendable {
    static let eventName = "device.app.lifecycle"
    static let attributeName = "ios.app.state"
    
    // The app has become active. Associated with UIKit notification applicationDidBecomeActive.
    case active = "active"
    // The app is now in the background. This value is associated with UIKit notification applicationDidEnterBackground.
    case background = "background"
    // The app is now in the foreground. This value is associated with UIKit notification applicationWillEnterForeground.
    case foreground = "foreground"
    // The app is now inactive. Associated with UIKit notification applicationWillResignActive.    Development
    case inactive = "inactive"
    // The app is about to terminate. Associated with UIKit notification applicationWillTerminate.
    case terminate = "terminate"
}

public protocol AppLifecycleLogging {
    
}

final class AppLifecycleLogger: AppLifecycleLogging {
    let appLifecycleManager: AppLifecycleManaging
    
    init(appLifecycleManager: AppLifecycleManaging, yield: @escaping (LDLogRecordBuilder) -> Void) {
        self.appLifecycleManager = appLifecycleManager
        
        Task(priority: .background) { [weak self] in
            guard let self else { return }
            
            for await event in await appLifecycleManager.events() {
                
            }
        }
    }
}
