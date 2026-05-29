import Foundation
import Combine
import UIKit
#if !LD_COCOAPODS
    import Common
#endif

final class LaunchTracker {
    typealias SceneData = SceneLaunchClassifier.SceneData

    struct LaunchInfo: Hashable {
        let sceneID: String?
        let start: TimeInterval
        let end: TimeInterval
        let type: SceneLaunchClassification
    }

    typealias PendingLaunch = SceneLaunchClassifier.PendingLaunch

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
            var classifierState = SceneLaunchClassifier.State(
                pendingSceneStarts: state.pendingSceneStarts,
                seenSceneIDs: state.seenSceneIDs,
                hasRecordedColdLaunch: state.hasRecordedColdLaunch
            )
            _ = SceneLaunchClassifier.reduce(state: &classifierState, action: .sceneWillEnterForeground(sceneData))
            state.pendingSceneStarts = classifierState.pendingSceneStarts
            state.seenSceneIDs = classifierState.seenSceneIDs
            state.hasRecordedColdLaunch = classifierState.hasRecordedColdLaunch

        case .sceneDidBecomeActive(let sceneData):
            var classifierState = SceneLaunchClassifier.State(
                pendingSceneStarts: state.pendingSceneStarts,
                seenSceneIDs: state.seenSceneIDs,
                hasRecordedColdLaunch: state.hasRecordedColdLaunch
            )
            guard let launchInfo = SceneLaunchClassifier.reduce(
                state: &classifierState,
                action: .sceneDidBecomeActive(sceneData)
            ) else { return }
            state.pendingSceneStarts = classifierState.pendingSceneStarts
            state.buffer.append(
                LaunchInfo(
                    sceneID: launchInfo.sceneID,
                    start: launchInfo.start,
                    end: launchInfo.end,
                    type: launchInfo.type
                )
            )

        case .launchInfoItemsWereTraced(let items):
            let traced = Set(items)
            state.buffer.removeAll { traced.contains($0) }
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
                let sceneData = SceneData(
                    sceneID: scene.session.persistentIdentifier,
                    systemUptime: ProcessInfo.processInfo.systemUptime
                )
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
