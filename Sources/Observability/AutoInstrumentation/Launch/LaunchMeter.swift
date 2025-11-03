#if canImport(UIKit)
import Foundation
import UIKit
import Common
//import StartupMetrics

enum LaunchType {
    case cold, warm
    
    var description: String {
        switch self {
        case .cold: return "cold"
        case .warm: return "warm"
        }
    }
}
struct LaunchStats: Hashable {
    let startTime: Date
    let endTime: Date
    let elapsedTime: Double
    let launchType: LaunchType
}

typealias DidGetStatistics = ([LaunchStats]) -> Void
public final class LaunchMeter {
    struct State {
        var launchStartUpDate: Date
        var launchStartUptime: TimeInterval
        var launchEndUpDate: Date?
        var launchEndUptime: TimeInterval?
        var lastBackgroundUptime: TimeInterval?
        
        var lastDidBecomeActiveUpTime: TimeInterval?
        var lastDidBecomeActiveUpDate: Date?
        var isFirstLaunchInProcess = true
        var hasRenderedFirstFrame = false
        var launchType = LaunchType.cold
        var lastLaunchDuration: TimeInterval = 0.0
        var statistics = [LaunchStats]()
    }
    enum Action {
        case didEnterBackground(currentUptime: TimeInterval, currentUpDate: Date)
        case appDidBecomeActive(currentUptime: TimeInterval, currentUpDate: Date)
        case willEnterForegroundNotification(currentUptime: TimeInterval, currentUpDate: Date)
        case displayLinkDidFrameUpdate(currentUptime: TimeInterval, currentUpDate: Date)
        
        case releaseBuffer
    }
    private let store: Store<State, Action>
    
    private var displayLink: CADisplayLink?
    private let processInfo: ProcessInfo
    
    private var observers = [UUID: DidGetStatistics]()
    
    
    public init() {
        let processInfo = ProcessInfo.processInfo
        self.store = .init(
            state: .init(launchStartUpDate: AppStartTime.stats.startDate, launchStartUptime: AppStartTime.stats.startTime),
            reducer: LaunchMeter.reduce(state:action:)
        )
        self.processInfo = processInfo
        self.addObservers()
    }

    @discardableResult
    func subscribe(block: @escaping DidGetStatistics) -> UUID {
        let id = UUID()
        observers[id] = block
        let statistics = store.state.statistics
        block(statistics)
        return id
    }
    
    func releaseBuffer() {
        store.dispatch(.releaseBuffer)
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForegroundNotification),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func willEnterForegroundNotification() {
        store.dispatch(.willEnterForegroundNotification(currentUptime: processInfo.systemUptime, currentUpDate: Date()))
    }
    
    @objc private func didEnterBackground() {
        displayLink?.invalidate()
        displayLink = nil
        store.dispatch(.didEnterBackground(currentUptime: processInfo.systemUptime, currentUpDate: Date()))
    }
    
    @objc private func appDidBecomeActive() {
        let currentUptime = processInfo.systemUptime
        store.dispatch(.appDidBecomeActive(currentUptime: currentUptime, currentUpDate: Date()))
        self.displayLink = CADisplayLink(target: self, selector: #selector(frameUpdate))
        self.displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func frameUpdate() {
        guard !store.state.hasRenderedFirstFrame else { return }
        store.dispatch(.displayLinkDidFrameUpdate(currentUptime: processInfo.systemUptime, currentUpDate: Date()))
        displayLink?.invalidate()
        displayLink = nil
        
        guard let statistics = store.state.statistics.last else { return }
        observers.values.forEach { $0([statistics]) }        
    }
    
    // MARK: - Update State
    private static func reduce(state: inout State, action: Action) {
        switch action {
        case .displayLinkDidFrameUpdate(let currentUptime, let currentUpDate):
            state.hasRenderedFirstFrame = true
            state.launchEndUpDate = currentUpDate
            
            guard !state.isFirstLaunchInProcess else {
                state.lastLaunchDuration = currentUptime - state.launchStartUptime
                let statistics = LaunchStats(
                    startTime: state.launchStartUpDate,
                    endTime: currentUpDate,
                    elapsedTime: state.lastLaunchDuration,
                    launchType: state.launchType
                )
                state.isFirstLaunchInProcess = false
                return state.statistics.append(statistics)
            }

            state.lastLaunchDuration = currentUptime - (state.lastDidBecomeActiveUpTime ?? 0.0)
            state.launchType = .warm
            
            let statistics = LaunchStats(
                startTime: state.lastDidBecomeActiveUpDate ?? Date(),
                endTime: state.launchEndUpDate ?? Date(),
                elapsedTime: state.lastLaunchDuration,
                launchType: state.launchType
            )
            state.statistics.append(statistics)
            
        case .didEnterBackground(let currentUptime, _):
            state.lastBackgroundUptime = currentUptime
        case .willEnterForegroundNotification(let currentUptime, let currentUpDate):
            state.lastDidBecomeActiveUpTime = currentUptime
            state.lastDidBecomeActiveUpDate = currentUpDate
        case .appDidBecomeActive(_, _):
            state.hasRenderedFirstFrame = false
        case .releaseBuffer:
            state.statistics.removeAll()
        }
    }
}
#endif
