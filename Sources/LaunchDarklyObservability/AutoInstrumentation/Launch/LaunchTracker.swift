import Foundation
import Combine

final class LaunchTracker {
    struct SceneData: Equatable {
        let sceneID: String?
        let systemUptime: TimeInterval
    }
    struct LaunchInfo: Hashable {
        let sceneID: String?
        let start: TimeInterval
        let end: TimeInterval
        let type: LaunchType
    }
    struct State {
        var sceneStartTimes: [String: TimeInterval]
        var hasRecordedColdLaunch = false
        var buffer: [LaunchInfo]
        
        init(
            sceneStartTimes: [String : TimeInterval] = [:],
            hasRecordedColdLaunch: Bool = false,
            buffer: [LaunchInfo] = []
        ) {
            self.sceneStartTimes = sceneStartTimes
            self.hasRecordedColdLaunch = hasRecordedColdLaunch
            self.buffer = buffer
        }
    }
    enum Action: Equatable {
        case sceneDidBecomeActive(SceneData)
        case sceneWillEnterForeground(SceneData)
        case launchInfoItemsWereTraced([LaunchInfo])
    }
    
    static func reduce(state: inout State, action: Action) {
        switch action {
        case .sceneDidBecomeActive(let sceneData):
            guard let id = sceneData.sceneID, let startUptime = state.sceneStartTimes[id] else {
                return
            }
            let endUptime = sceneData.systemUptime
//            let duration = endUptime - startUptime
            let launchType: LaunchType = state.hasRecordedColdLaunch ? .warm : .cold
            // Mark cold launch recorded once
            if !state.hasRecordedColdLaunch {
                state.hasRecordedColdLaunch = true
            }
            let launchInfo = LaunchInfo(sceneID: id, start: startUptime, end: endUptime, type: launchType)
            state.buffer.append(launchInfo)
        case .sceneWillEnterForeground(let sceneData):
            guard let id = sceneData.sceneID else {
                return
            }
            state.sceneStartTimes[id] = state.hasRecordedColdLaunch ? ProcessInfo.processInfo.systemUptime : AppStartTime.stats.startTime
        case .launchInfoItemsWereTraced(let items):
            state.buffer.removeAll(where: { items.contains($0) })
        }
        
    }
    
    private var displayLink: CADisplayLink?
    private var cancellables: Set<AnyCancellable>
    private let store: Store<State, Action>
    
    var state: State {
        store.state
    }
    
    init(initialState: State = .init()) {
        let store = Store<State, Action>(state: initialState, reducer: LaunchTracker.reduce(state:action:))
        
        self.store = store
        self.cancellables = []
//        self.displayLink = CADisplayLink(target: self, selector: #selector(frameUpdate))
        
        self.cancellables.insert(self.subscribeToSceneNotifications(usingStore: store))
//        self.displayLink?.add(to: .main, forMode: .common)
    }
}

extension LaunchTracker: AutoInstrumentation {
    func start() {}
    
    func stop() {}
}

extension LaunchTracker {
    func trace(
        using tracingApi: TraceClient
    ) {
        let bufferedItems = store.state.buffer
        bufferedItems.forEach { item in
            tracingApi
                .startSpan(
                    name: "AppStart",
                    attributes: [
                        "start.type": .string(
                            item.type.description
                        ),
                        "duration": .double(
                            item.end - item.start
                        )
                    ],
                    startTime: Date(
                        timeIntervalSinceNow: item.start
                    )
                )
                .end(
                    time: Date(
                        timeIntervalSinceNow: item.end
                    )
                )
            print("launch: \(item.type.description) lasted: \(item.end - item.start)s")
        }
        store.dispatch(.launchInfoItemsWereTraced(bufferedItems))
    }
}

import UIKit
import Combine
import Common

extension LaunchTracker {
    func subscribeToSceneNotifications(usingStore store: Store<State, Action>) -> AnyCancellable {
        Publishers.MergeMany(
            NotificationCenter.default.publisher(for: UIScene.didActivateNotification),
            NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification),
        )
        .subscribe(on: RunLoop.main)
        .receive(on: RunLoop.main)
        .sink { notification in
            switch notification.name {
            case UIScene.didActivateNotification:
                guard let scene = notification.object as? UIScene else { return }
                let sceneData = SceneData(
                    sceneID: scene.session.persistentIdentifier,
                    systemUptime: ProcessInfo.processInfo.systemUptime
                )
                store.dispatch(.sceneDidBecomeActive(sceneData))
            case UIScene.willEnterForegroundNotification:
                guard let scene = notification.object as? UIScene else { return }
                let sceneData = SceneData(
                    sceneID: scene.session.persistentIdentifier,
                    systemUptime: ProcessInfo.processInfo.systemUptime
                )
                store.dispatch(.sceneWillEnterForeground(sceneData))
            default:
                break
            }
        }
    }
}

