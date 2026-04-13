import UIKit

class CatSceneDelegate: UIResponder, UISceneDelegate {
    var window: UIWindow?

    private var foregroundUptime: TimeInterval?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let detail: CatDetailViewController
        if let activity = connectionOptions.userActivities.first ?? session.stateRestorationActivity,
           let identifier = activity.targetContentIdentifier {
            detail = CatDetailViewController(catName: identifier)
        } else {
            detail = CatDetailViewController(catName: "default")
        }

        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = detail
            window.backgroundColor = .white
            self.window = window
            window.makeKeyAndVisible()
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        foregroundUptime = ProcessInfo.processInfo.systemUptime
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        let activateUptime = ProcessInfo.processInfo.systemUptime
        if let foregroundUptime {
            SceneLaunchEventLog.shared.record(
                sceneID: scene.session.persistentIdentifier,
                foregroundUptime: foregroundUptime,
                activateUptime: activateUptime
            )
            self.foregroundUptime = nil
        }
        LaunchStatsOverlayView.install(in: window)
    }

    override func restoreUserActivityState(_ activity: NSUserActivity) {
        super.restoreUserActivityState(activity)
    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        return scene.userActivity
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        scene.session.stateRestorationActivity = scene.userActivity
    }

    func sceneWillResignActive(_ scene: UIScene) {
        scene.session.stateRestorationActivity = scene.userActivity
    }
}
