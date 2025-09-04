import UIKit.UIApplication

enum AppLifecycleState {
    case unattached
    case foregroundInactive
    case foregroundActive
    case suspended
    case background
    
    static let notInForeground: [Self] = [
        .unattached, .suspended, .background
    ]
}
private func update(
    state: AppLifecycleState,
    message: Notification.Name
) -> AppLifecycleState {
    switch message {
    case UIApplication.didFinishLaunchingNotification:
        return .foregroundInactive
        
    case UIApplication.willResignActiveNotification:
        return .background
    case UIApplication.didEnterBackgroundNotification:
        return .background
        
    case UIApplication.willEnterForegroundNotification:
        return .foregroundInactive
    case UIApplication.didBecomeActiveNotification:
        return .foregroundActive
    
    case UIApplication.willTerminateNotification:
        return .suspended
    default:
        return state
    }
}
