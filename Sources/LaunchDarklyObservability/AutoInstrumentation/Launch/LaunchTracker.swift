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
        var coldLaunchStart: TimeInterval
        var coldLaunchEnd: TimeInterval?
        var warmLaunchStarts: [String: TimeInterval]
        var hasRenderedFirstFrame = false
        var buffer: [LaunchInfo]
        
        init(
            coldLaunchStart: TimeInterval = AppStartTime.stats.startTime,
            coldLaunchEnd: TimeInterval? = nil,
            warmLaunchStarts: [String : TimeInterval] = [:],
            hasRenderedFirstFrame: Bool = false,
            buffer: [LaunchInfo] = []
        ) {
            self.coldLaunchStart = coldLaunchStart
            self.coldLaunchEnd = coldLaunchEnd
            self.warmLaunchStarts = warmLaunchStarts
            self.hasRenderedFirstFrame = hasRenderedFirstFrame
            self.buffer = buffer
        }
    }
    enum Action: Equatable {
        case coldLaunchEnded(SceneData)
        case warmLaunchStarted(SceneData)
        case warmLaunchEnded(SceneData)
        case displayLinkDidFrameUpdate(SceneData)
        case launchInfoItemsWereTraced([LaunchInfo])
    }
    
    static func reduce(state: inout State, action: Action) {
        switch action {
        case .coldLaunchEnded(let sceneData):
            state.coldLaunchEnd = sceneData.systemUptime
            let start = state.coldLaunchStart
            let end = sceneData.systemUptime
            let launchInfo = LaunchInfo(sceneID: nil, start: start, end: end, type: .cold)
            state.buffer.append(launchInfo)
        case .warmLaunchStarted(let sceneData):
            guard let sceneID = sceneData.sceneID else { return }
            guard state.warmLaunchStarts[sceneID] == nil else { return }
            state.warmLaunchStarts[sceneID] = sceneData.systemUptime
        case .warmLaunchEnded(let sceneData):
            guard let sceneID = sceneData.sceneID else { return }
            let end = sceneData.systemUptime
            guard let start = state.warmLaunchStarts.removeValue(forKey: sceneID) else {
                return
            }
            let launchInfo = LaunchInfo(sceneID: sceneID, start: start, end: end, type: .warm)
            state.buffer.append(launchInfo)
        case .displayLinkDidFrameUpdate(let sceneData):
            guard !state.hasRenderedFirstFrame else { return }
            state.hasRenderedFirstFrame = true
            state.coldLaunchEnd = sceneData.systemUptime
            let start = state.coldLaunchStart
            let end = sceneData.systemUptime
            let launchInfo = LaunchInfo(sceneID: nil, start: start, end: end, type: .cold)
            state.buffer.append(launchInfo)
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
        self.displayLink = CADisplayLink(target: self, selector: #selector(frameUpdate))
        
        self.cancellables.insert(self.subscribeToSceneNotifications(usingStore: store))
        self.displayLink?.add(to: .main, forMode: .common)
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
        }
        store.dispatch(.launchInfoItemsWereTraced(bufferedItems))
    }
}

import UIKit
import Combine
import Common

extension LaunchTracker {
    @objc private func frameUpdate() {
        guard !store.state.hasRenderedFirstFrame else { return }
        displayLink?.invalidate()
        displayLink = nil
        store
            .dispatch(
                .displayLinkDidFrameUpdate(
                    .init(
                        sceneID: nil,
                        systemUptime: ProcessInfo.processInfo.systemUptime
                    )
                )
            )
    }
}

extension LaunchTracker {
    func subscribeToSceneNotifications(usingStore store: Store<State, Action>) -> AnyCancellable {
        Publishers.MergeMany(
            NotificationCenter.default.publisher(for: UIScene.willConnectNotification),
            NotificationCenter.default.publisher(for: UIScene.didActivateNotification),
            NotificationCenter.default.publisher(for: UIScene.willDeactivateNotification),
            NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification),
            NotificationCenter.default.publisher(for: UIScene.didEnterBackgroundNotification),
        )
        .subscribe(on: RunLoop.main)
        .receive(on: RunLoop.main)
        .sink { notification in
            switch notification.name {
            case UIScene.willConnectNotification:
                guard let scene = notification.object as? UIScene else { return }
                let sceneData = SceneData(
                    sceneID: scene.session.persistentIdentifier,
                    systemUptime: ProcessInfo.processInfo.systemUptime
                )
                print("UIScene.willConnectNotification \(sceneData)")
                store.dispatch(.warmLaunchStarted(sceneData))
            case UIScene.didActivateNotification:
                guard let scene = notification.object as? UIScene else { return }
                let sceneData = SceneData(
                    sceneID: scene.session.persistentIdentifier,
                    systemUptime: ProcessInfo.processInfo.systemUptime
                )
                print("UIScene.didActivateNotification \(sceneData)")
                store.dispatch(.warmLaunchEnded(sceneData))
            case UIScene.willDeactivateNotification:
                guard let scene = notification.object as? UIScene else { return }
                let sceneData = SceneData(
                    sceneID: scene.session.persistentIdentifier,
                    systemUptime: ProcessInfo.processInfo.systemUptime
                )
                print("UIScene.willDeactivateNotification \(sceneData)")
            case UIScene.willEnterForegroundNotification:
                guard let scene = notification.object as? UIScene else { return }
                let sceneData = SceneData(
                    sceneID: scene.session.persistentIdentifier,
                    systemUptime: ProcessInfo.processInfo.systemUptime
                )
                print("UIScene.willEnterForegroundNotification \(sceneData)")
                store.dispatch(.warmLaunchStarted(sceneData))
            case UIScene.didEnterBackgroundNotification:
                
                guard let scene = notification.object as? UIScene else { return }
                let sceneData = SceneData(
                    sceneID: scene.session.persistentIdentifier,
                    systemUptime: ProcessInfo.processInfo.systemUptime
                )
                print("UIScene.didEnterBackgroundNotification \(sceneData)")
                store.dispatch(.warmLaunchEnded(sceneData))
            default:
                break
            }
        }
    }
}
