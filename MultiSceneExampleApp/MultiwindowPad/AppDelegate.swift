import UIKit
import LaunchDarklyObservability

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    let client = Client()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        LDObserve.shared.start()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let activity = options.userActivities.first, activity.activityType == "com.donnywals.viewCat" {
            return UISceneConfiguration(name: "Cat Detail", sessionRole: connectingSceneSession.role)
        }
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}

// MARK: - Scene Launch Tracking (demo)

enum SceneLaunchType: String {
    case cold = "Cold Launch"
    case warm = "Warm Launch"
    case sceneCreation = "Scene Created"

    init(_ classification: SceneLaunchClassification) {
        switch classification {
        case .cold: self = .cold
        case .warm: self = .warm
        case .sceneCreation: self = .sceneCreation
        }
    }

    var color: UIColor {
        switch self {
        case .cold: return .systemBlue
        case .warm: return .systemGreen
        case .sceneCreation: return .systemOrange
        }
    }
}

struct SceneLaunchEvent {
    let sceneID: String
    let type: SceneLaunchType
    let durationMs: Double
    let date: Date
}

extension Notification.Name {
    static let sceneLaunchEventRecorded = Notification.Name("SceneLaunchEventRecorded")
}

/// Shared log that classifies scene lifecycle events into cold / warm / sceneCreation launches
/// and stores them for display.
final class SceneLaunchEventLog {
    static let shared = SceneLaunchEventLog()
    private init() {}

    private(set) var events: [SceneLaunchEvent] = []
    private var classifier = SceneLaunchClassifier()

    /// Call from `sceneWillEnterForeground` and `sceneDidBecomeActive` to record one launch event.
    /// - Parameters:
    ///   - sceneID: The persistent session identifier of the scene.
    ///   - foregroundUptime: `ProcessInfo.processInfo.systemUptime` captured in `sceneWillEnterForeground`.
    ///   - activateUptime: `ProcessInfo.processInfo.systemUptime` captured in `sceneDidBecomeActive`.
    func record(sceneID: String, foregroundUptime: TimeInterval, activateUptime: TimeInterval) {
        classifier.sceneWillEnterForeground(.init(sceneID: sceneID, systemUptime: foregroundUptime))
        guard let launchInfo = classifier.sceneDidBecomeActive(.init(sceneID: sceneID, systemUptime: activateUptime)) else {
            return
        }

        let durationMs = max(launchInfo.end - launchInfo.start, 0) * 1000
        let shortID = String(sceneID.prefix(8))
        let event = SceneLaunchEvent(
            sceneID: shortID,
            type: SceneLaunchType(launchInfo.type),
            durationMs: durationMs,
            date: Date()
        )
        events.append(event)
        NotificationCenter.default.post(name: .sceneLaunchEventRecorded, object: event)
    }
}
