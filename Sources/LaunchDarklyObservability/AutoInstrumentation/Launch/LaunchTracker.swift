import Foundation
import Combine
import UIKit
#if !LD_COCOAPODS
    import Common
#endif

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
            state.sceneStartTimes[id] = sceneData.systemUptime
        case .launchInfoItemsWereTraced(let items):
            state.buffer.removeAll(where: { items.contains($0) })
        }
        
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let store: Store<State, Action>
    
    var state: State {
        store.state
    }
    
    init(initialState: State = .init()) {
        let store = Store<State, Action>(state: initialState, reducer: LaunchTracker.reduce(state:action:))
        
        self.store = store
        
        self.subscribeToSceneNotifications(usingStore: store)
    }
}

extension LaunchTracker {
    func trace(
        using tracingApi: TraceClient
    ) async {
        await MainActor.run { [weak self] in
            guard let self else { return }
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
                            timeIntervalSinceNow: -item.start
                        )
                    )
                    .end(
                        time: Date(
                            timeIntervalSinceNow: -item.end
                        )
                    )
            }
            store.dispatch(.launchInfoItemsWereTraced(bufferedItems))
        }
    }
}

extension LaunchTracker {
    func subscribeToSceneNotifications(usingStore store: Store<State, Action>) {
        NotificationCenter.default.publisher(for: UIScene.didActivateNotification)
            .subscribe(on: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { notification in
                guard let scene = notification.object as? UIScene else { return }
                let sceneData = SceneData(
                    sceneID: scene.session.persistentIdentifier,
                    systemUptime: ProcessInfo.processInfo.systemUptime
                )
                store.dispatch(.sceneDidBecomeActive(sceneData))
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification)
            .subscribe(on: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { notification in
                guard let scene = notification.object as? UIScene else { return }
                
                let systemUptime = store.state.hasRecordedColdLaunch ? ProcessInfo.processInfo.systemUptime : AppStartTime.stats.startTime
                let sceneData = SceneData(
                    sceneID: scene.session.persistentIdentifier,
                    systemUptime: systemUptime
                )
                store.dispatch(.sceneWillEnterForeground(sceneData))
            }
            .store(in: &cancellables)
    }
}

