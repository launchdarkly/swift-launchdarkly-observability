#if canImport(UIKit)
import UIKit
import Testing
@testable import LaunchDarklyObservability

// Top-level doubles so `NSStringFromClass` yields readable module-qualified names
// (nested types mangle to `_Tt...`, which the filter would reject).
final class ProfileViewController: UIViewController {}
final class CheckoutVC: UIViewController {}
final class CustomNamedController: UIViewController, LDScreenNameProviding {
    var ldScreenName: String? { "My Custom Screen" }
    var ldScreenCategory: String? { "Onboarding" }
}

@MainActor
struct ViewControllerScreenSourceTests {
    @Test("Container and system controllers are filtered out")
    func filtersContainerAndSystemControllers() {
        #expect(ViewControllerScreenSource.shouldTrack(UINavigationController()) == false)
        #expect(ViewControllerScreenSource.shouldTrack(UITabBarController()) == false)
        #expect(ViewControllerScreenSource.shouldTrack(
            UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        ) == false)
        // Bare UIViewController is a UIKit (`UI`-prefixed) class and is filtered.
        #expect(ViewControllerScreenSource.shouldTrack(UIViewController()) == false)
    }

    @Test("App-defined controllers are tracked")
    func tracksAppControllers() {
        #expect(ViewControllerScreenSource.shouldTrack(ProfileViewController()) == true)
    }

    @Test("Provider-conforming controllers are always tracked")
    func tracksProviderControllers() {
        #expect(ViewControllerScreenSource.shouldTrack(CustomNamedController()) == true)
    }

    @Test("Class name is cleaned into a readable default name")
    func cleansClassName() {
        #expect(ViewControllerScreenSource.cleanedName(fromClass: "ProfileViewController") == "Profile")
        #expect(ViewControllerScreenSource.cleanedName(fromClass: "CheckoutVC") == "Checkout")
        #expect(ViewControllerScreenSource.cleanedName(fromClass: "MyApp.HomeController") == "Home")
        #expect(ViewControllerScreenSource.cleanedName(fromClass: "Dashboard") == "Dashboard")
    }

    @Test("screenView derives name, class and id from the controller")
    func derivesScreenView() throws {
        let screen = try #require(ViewControllerScreenSource.screenView(for: ProfileViewController()))
        #expect(screen.name == "Profile")
        #expect(screen.screenClass?.contains("ProfileViewController") == true)
        #expect(screen.screenId?.contains("ProfileViewController") == true)
        #expect(screen.category == nil)
    }

    @Test("VC title overrides the derived class name")
    func titleOverridesDerivedName() throws {
        let vc = ProfileViewController()
        vc.title = "Your Profile"
        let screen = try #require(ViewControllerScreenSource.screenView(for: vc))
        #expect(screen.name == "Your Profile")
    }

    @Test("Provider name and category take precedence")
    func providerTakesPrecedence() throws {
        let screen = try #require(ViewControllerScreenSource.screenView(for: CustomNamedController()))
        #expect(screen.name == "My Custom Screen")
        #expect(screen.category == "Onboarding")
    }

    @Test("Filtered controllers produce no screen view")
    func filteredControllersProduceNil() {
        #expect(ViewControllerScreenSource.screenView(for: UINavigationController()) == nil)
    }

    @Test("topViewController returns the root for a plain controller")
    func topViewControllerPlain() {
        let root = ProfileViewController()
        #expect(ViewControllerScreenSource.topViewController(from: root) === root)
    }

    @Test("topViewController descends into a navigation controller's visible child")
    func topViewControllerNavigation() {
        let visible = ProfileViewController()
        let nav = UINavigationController(rootViewController: visible)
        #expect(ViewControllerScreenSource.topViewController(from: nav) === visible)
    }

    @Test("topViewController descends into a tab bar's selected child")
    func topViewControllerTabBar() {
        let first = ProfileViewController()
        let second = CheckoutVC()
        let tab = UITabBarController()
        tab.viewControllers = [first, second]
        tab.selectedIndex = 1
        #expect(ViewControllerScreenSource.topViewController(from: tab) === second)
    }

    @Test("topViewController follows presented controllers")
    func topViewControllerPresented() async {
        // A presented controller on top of a nav stack should win over the nav's visible child.
        // Presentation only takes effect when the presenter is in a live window hierarchy.
        let base = ProfileViewController()
        let nav = UINavigationController(rootViewController: base)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = nav
        window.makeKeyAndVisible()

        let presented = CheckoutVC()
        await withCheckedContinuation { continuation in
            nav.present(presented, animated: false) { continuation.resume() }
        }

        #expect(ViewControllerScreenSource.topViewController(from: nav) === presented)
        window.isHidden = true
    }

    @Test("topViewController is nil for no root")
    func topViewControllerNil() {
        #expect(ViewControllerScreenSource.topViewController(from: nil) == nil)
    }
}
#endif
