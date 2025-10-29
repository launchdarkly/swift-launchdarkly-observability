#if canImport(UIKit)
import UIKit
import Combine

public final class LaunchPerformanceTiming {
    enum LaunchType {
        case cold, warm
    }
    
    private init() {
        NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification)
            .subscribe(on: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.trackLaunch()
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIScene.didActivateNotification)
            .subscribe(on: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.measure()
            }
            .store(in: &cancellables)
    }
    
    func trackLaunch() {
        self.hasLaunchedOnce = true
        self.startTime = CACurrentMediaTime()
    }
    
    func measure() {
        let timeElapsed = CACurrentMediaTime() - startTime
        print("Time: - \(timeElapsed) for \(self.launchType) launch")
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private var hasLaunchedOnce = false
    private var startTime = CACurrentMediaTime()
    var launchType: LaunchType { return hasLaunchedOnce ? .warm : .cold }
    public static let instance = LaunchPerformanceTiming()
}

@discardableResult func measure<A>(name: String = "", _ block: () -> A) -> A {
    let startTime = CACurrentMediaTime()
    let result = block()
    let timeElapsed = CACurrentMediaTime() - startTime
    print("Time: \(name) - \(timeElapsed)")
    NotificationCenter.default.post(name: .performanceTiming, object: nil)
    return result
}

//final class PerformanceTiming {
//    let startTime = CACurrentMediaTime()
//    
//    @discardableResult
//    func measure<A>(name: String = "", _ block: () -> A) -> A {
//        let startTime = CACurrentMediaTime()
//        let result = block()
//        let timeElapsed = CACurrentMediaTime() - startTime
//        print("Time: \(name) - \(timeElapsed)")
//        NotificationCenter.default.post(name: .performanceTiming, object: nil)
//        return result
//    }
//}

extension Notification.Name {
    static let performanceTiming = Notification.Name("com.launchdarkly.PerformanceTiming.measure")
}
#endif
