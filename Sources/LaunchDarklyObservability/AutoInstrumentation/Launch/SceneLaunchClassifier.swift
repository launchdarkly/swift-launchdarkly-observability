#if canImport(UIKit)
import Foundation

public enum SceneLaunchClassification: Hashable {
    case cold
    case warm
    case sceneCreation

    var description: String {
        switch self {
        case .cold: return "cold"
        case .warm: return "warm"
        case .sceneCreation: return "sceneCreation"
        }
    }

}

public struct SceneLaunchClassifier {
    public struct SceneData: Equatable {
        public let sceneID: String?
        public let systemUptime: TimeInterval

        public init(sceneID: String?, systemUptime: TimeInterval) {
            self.sceneID = sceneID
            self.systemUptime = systemUptime
        }
    }

    public struct LaunchInfo: Hashable {
        public let sceneID: String
        public let start: TimeInterval
        public let end: TimeInterval
        public let type: SceneLaunchClassification
    }

    struct PendingLaunch {
        let startTime: TimeInterval
        let type: SceneLaunchClassification
    }

    struct State {
        /// Scenes that have a start time recorded but haven't activated yet.
        var pendingSceneStarts: [String: PendingLaunch]
        /// Scene IDs we have seen at least once (used to distinguish first-time vs returning scenes).
        var seenSceneIDs: Set<String>
        var hasRecordedColdLaunch: Bool

        init(
            pendingSceneStarts: [String: PendingLaunch] = [:],
            seenSceneIDs: Set<String> = [],
            hasRecordedColdLaunch: Bool = false
        ) {
            self.pendingSceneStarts = pendingSceneStarts
            self.seenSceneIDs = seenSceneIDs
            self.hasRecordedColdLaunch = hasRecordedColdLaunch
        }
    }

    enum Action: Equatable {
        /// Fires when a scene enters the foreground. For a brand-new scene this also determines
        /// whether the launch is cold or sceneCreation; for a returning scene it is warm.
        case sceneWillEnterForeground(SceneData)
        /// Fires when a scene becomes interactive — marks the end of the launch window.
        case sceneDidBecomeActive(SceneData)
    }

    var state: State
    private let processStartUptime: TimeInterval

    public init(processStartUptime: TimeInterval = AppStartTime.stats.startTime) {
        self.state = State()
        self.processStartUptime = processStartUptime
    }

    public mutating func sceneWillEnterForeground(_ sceneData: SceneData) {
        Self.reduce(state: &state, action: .sceneWillEnterForeground(sceneData), processStartUptime: processStartUptime)
    }

    public mutating func sceneDidBecomeActive(_ sceneData: SceneData) -> LaunchInfo? {
        Self.reduce(state: &state, action: .sceneDidBecomeActive(sceneData), processStartUptime: processStartUptime)
    }

    static func reduce(
        state: inout State,
        action: Action,
        processStartUptime: TimeInterval = AppStartTime.stats.startTime
    ) -> LaunchInfo? {
        switch action {
        case .sceneWillEnterForeground(let sceneData):
            guard let id = sceneData.sceneID else { return nil }

            if !state.seenSceneIDs.contains(id) {
                // First time we see this scene — cold or sceneCreation.
                state.seenSceneIDs.insert(id)
                if !state.hasRecordedColdLaunch {
                    state.hasRecordedColdLaunch = true
                    // Process-start uptime so duration spans from process creation, not foreground notification time.
                    state.pendingSceneStarts[id] = PendingLaunch(
                        startTime: processStartUptime,
                        type: .cold
                    )
                } else {
                    state.pendingSceneStarts[id] = PendingLaunch(startTime: sceneData.systemUptime, type: .sceneCreation)
                }
            } else {
                // Scene has been active before — warm launch.
                // Guard against duplicate events while a measurement is already in progress.
                guard state.pendingSceneStarts[id] == nil else { return nil }
                state.pendingSceneStarts[id] = PendingLaunch(startTime: sceneData.systemUptime, type: .warm)
            }

            return nil

        case .sceneDidBecomeActive(let sceneData):
            guard let id = sceneData.sceneID,
                  let pending = state.pendingSceneStarts[id] else { return nil }
            let launchInfo = LaunchInfo(
                sceneID: id,
                start: pending.startTime,
                end: sceneData.systemUptime,
                type: pending.type
            )
            state.pendingSceneStarts.removeValue(forKey: id)
            return launchInfo
        }
    }
}
#endif
