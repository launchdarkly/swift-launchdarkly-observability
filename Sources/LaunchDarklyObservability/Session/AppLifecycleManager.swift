import UIKit
import Combine
#if !LD_COCOAPODS
    import Common
#endif

public enum AppLifeCycleEvent {
    case didFinishLaunching
    case willEnterForeground
    case didBecomeActive
    case willResignActive
    case didEnterBackground
    case willTerminate
}

public protocol AppLifecycleManaging: AnyObject {
    func publisher() -> AnyPublisher<AppLifeCycleEvent, Never>
}

final class AppLifecycleManager: AppLifecycleManaging {
    private let subject = PassthroughSubject<AppLifeCycleEvent, Never>()
    private var observers = [NSObjectProtocol]()
    
    init() {
        observeLifecycleNotifications()
    }
    
    // Exposes a Combine publisher that supports multiple subscribers.
    // Subscribers will receive lifecycle events as they occur.
    func publisher() -> AnyPublisher<AppLifeCycleEvent, Never> {
        subject.eraseToAnyPublisher()
    }
    
    private func observeLifecycleNotifications() {
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didFinishLaunchingNotification, object: nil, queue: .main) { [weak self] _ in
            self?.didFinishLaunching()
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleDidBecomeActive()
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleWillResignActive()
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleDidEnterBackground()
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleWillEnterForeground()
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleWillTerminate()
        })
    }
    
    deinit {
        observers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
    }

    func send(_ event: AppLifeCycleEvent) {
        Task(priority: .background) { [weak self] in
            guard let self else { return }
            self.subject.send(event)
        }
    }
    
    private func didFinishLaunching() {
        send(.didFinishLaunching)
    }
    
    private func handleDidBecomeActive() {
        send(.didBecomeActive)
    }
    
    private func handleWillResignActive() {
        send(.willResignActive)
    }
    
    private func handleDidEnterBackground() {
        send(.didEnterBackground)
    }
    
    private func handleWillEnterForeground() {
        send(.willEnterForeground)
    }
    
    private func handleWillTerminate() {
        send(.willTerminate)
    }
}
