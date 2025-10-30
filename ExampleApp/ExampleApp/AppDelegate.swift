import UIKit
import LaunchDarklyObservability

final class AppDelegate: NSObject, UIApplicationDelegate {
    let client = Client()
    
    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        _ = LaunchMeter.shared
        return true
    }
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        client.start()
        return true
    }
}
