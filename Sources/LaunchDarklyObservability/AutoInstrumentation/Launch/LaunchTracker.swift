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

    struct PendingLaunch {
        let startTime: TimeInterval
        let type: LaunchType
    }

    struct State {
        /// Scenes that have a start time recorded but haven't activated yet.
        var pendingSceneStarts: [String: PendingLaunch]
        /// Scene IDs we have seen at least once (used to distinguish first-time vs returning scenes).
        var seenSceneIDs: Set<String>
        var hasRecordedColdLaunch: Bool
        var buffer: [LaunchInfo]

        init(
            pendingSceneStarts: [String: PendingLaunch] = [:],
            seenSceneIDs: Set<String> = [],
            hasRecordedColdLaunch: Bool = false,
            buffer: [LaunchInfo] = []
        ) {
            self.pendingSceneStarts = pendingSceneStarts
            self.seenSceneIDs = seenSceneIDs
            self.hasRecordedColdLaunch = hasRecordedColdLaunch
            self.buffer = buffer
        }
    }

    enum Action: Equatable {
        /// Fires when a scene enters the foreground. For a brand-new scene this also determines
        /// whether the launch is cold or sceneCreation; for a returning scene it is warm.
        case sceneWillEnterForeground(SceneData)
        /// Fires when a scene becomes interactive — marks the end of the launch window.
        case sceneDidBecomeActive(SceneData)
        /// Called after buffered items have been sent to the tracing backend.
        case launchInfoItemsWereTraced([LaunchInfo])
    }

    static func reduce(state: inout State, action: Action) {
        switch action {
        case .sceneWillEnterForeground(let sceneData):
            guard let id = sceneData.sceneID else { return }

            if !state.seenSceneIDs.contains(id) {
                // First time we see this scene — cold or sceneCreation.
                state.seenSceneIDs.insert(id)
                if !state.hasRecordedColdLaunch {
                    state.hasRecordedColdLaunch = true
                    state.pendingSceneStarts[id] = PendingLaunch(startTime: sceneData.systemUptime, type: .cold)
                } else {
                    state.pendingSceneStarts[id] = PendingLaunch(startTime: sceneData.systemUptime, type: .sceneCreation)
                }
            } else {
                // Scene has been active before — warm launch.
                // Guard against duplicate events while a measurement is already in progress.
                guard state.pendingSceneStarts[id] == nil else { return }
                state.pendingSceneStarts[id] = PendingLaunch(startTime: sceneData.systemUptime, type: .warm)
            }

        case .sceneDidBecomeActive(let sceneData):
            guard let id = sceneData.sceneID,
                  let pending = state.pendingSceneStarts[id] else { return }
            let launchInfo = LaunchInfo(
                sceneID: id,
                start: pending.startTime,
                end: sceneData.systemUptime,
                type: pending.type
            )
            state.buffer.append(launchInfo)
            state.pendingSceneStarts.removeValue(forKey: id)

        case .launchInfoItemsWereTraced(let items):
            state.buffer = Array(Set(state.buffer).subtracting(items))
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
    func trace(using tracingApi: TraceClient) async {
        await MainActor.run { [weak self] in
            guard let self else { return }
            let bufferedItems = store.state.buffer
            let currentUptime = ProcessInfo.processInfo.systemUptime
            let now = Date()
            bufferedItems.forEach { item in
                tracingApi
                    .startSpan(
                        name: "AppStart",
                        attributes: [
                            "start.type": .string(item.type.description),
                            "duration": .double(item.end - item.start)
                        ],
                        startTime: now.addingTimeInterval(item.start - currentUptime)
                    )
                    .end(time: now.addingTimeInterval(item.end - currentUptime))
            }
            store.dispatch(.launchInfoItemsWereTraced(bufferedItems))
        }
    }
}

extension LaunchTracker {
    func subscribeToSceneNotifications(usingStore store: Store<State, Action>) {
        NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification)
            .subscribe(on: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { notification in
                guard let scene = notification.object as? UIScene else { return }
                let id = scene.session.persistentIdentifier
                // Substitute the process-start uptime for cold launches so the measured
                // duration covers the full time from when the process was created.
                let isFirstTime = !store.state.seenSceneIDs.contains(id)
                let isColdLaunch = isFirstTime && !store.state.hasRecordedColdLaunch
                let systemUptime = isColdLaunch
                    ? AppStartTime.stats.startTime
                    : ProcessInfo.processInfo.systemUptime
                let sceneData = SceneData(sceneID: id, systemUptime: systemUptime)
                store.dispatch(.sceneWillEnterForeground(sceneData))
            }
            .store(in: &cancellables)

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
    }
}
