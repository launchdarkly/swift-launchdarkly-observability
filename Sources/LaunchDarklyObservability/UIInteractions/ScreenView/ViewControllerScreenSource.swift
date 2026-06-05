#if canImport(UIKit)
import UIKit

/// Captures `screen_view` events by swizzling `UIViewController.viewDidAppear(_:)` and
/// `UIViewController.viewDidDisappear(_:)`.
///
/// Mirrors the swizzle approach in `UIWindowSwizzleSource`: it replaces the
/// implementation, calls the original, then yields the appearing controller as a
/// derived `ScreenView`. Container and system controllers are filtered out so the
/// stream reflects user-meaningful screens only.
///
/// `viewDidAppear` can fire more than once for the same on-screen controller without it
/// actually leaving the screen — e.g. a cancelled interactive dismissal, or dismissing an
/// overlay/modal that did not cause this controller to disappear. To avoid duplicate
/// `Navigate`/`screen_view` events we track which controllers are currently on screen (via
/// `viewDidDisappear`) and only yield the first `viewDidAppear` since the controller last left.
/// A genuine re-appearance (the controller disappeared and came back) still yields, even when an
/// intervening cover was not itself a tracked screen.
final class ViewControllerScreenSource {
    typealias ViewLifecycleRef = @convention(c) (UIViewController, Selector, Bool) -> Void
    private static let viewDidAppearSelector = #selector(UIViewController.viewDidAppear(_:))
    private static let viewDidDisappearSelector = #selector(UIViewController.viewDidDisappear(_:))

    private var isActive = false
    private var originalAppearIMP: IMP?
    private var originalDisappearIMP: IMP?
    private var yield: ((ScreenView) -> Void)?

    /// Controllers currently on screen (appeared and not yet disappeared). Weak so we never
    /// retain controllers; accessed on the main thread only (UIKit lifecycle callbacks).
    private let onScreen = NSHashTable<UIViewController>.weakObjects()

    init() {}

    func start(yield: @escaping (ScreenView) -> Void) {
        guard !isActive else { return }
        guard let appearMethod = class_getInstanceMethod(
            UIViewController.self,
            ViewControllerScreenSource.viewDidAppearSelector
        ), let disappearMethod = class_getInstanceMethod(
            UIViewController.self,
            ViewControllerScreenSource.viewDidDisappearSelector
        ) else { return }

        self.yield = yield

        let appearBlock: @convention(block) (UIViewController, Bool) -> Void = { [weak self] viewController, animated in
            if let originalIMP = self?.originalAppearIMP {
                let castedIMP = unsafeBitCast(originalIMP, to: ViewLifecycleRef.self)
                castedIMP(viewController, ViewControllerScreenSource.viewDidAppearSelector, animated)
            }

            guard let self else { return }
            // Drop spurious repeat appears that aren't preceded by a disappear; a real
            // re-appearance always follows a `viewDidDisappear` that removed the controller.
            guard !self.onScreen.contains(viewController) else { return }
            self.onScreen.add(viewController)

            if let screen = ViewControllerScreenSource.screenView(for: viewController) {
                self.yield?(screen)
            }
        }

        let disappearBlock: @convention(block) (UIViewController, Bool) -> Void = { [weak self] viewController, animated in
            if let originalIMP = self?.originalDisappearIMP {
                let castedIMP = unsafeBitCast(originalIMP, to: ViewLifecycleRef.self)
                castedIMP(viewController, ViewControllerScreenSource.viewDidDisappearSelector, animated)
            }
            self?.onScreen.remove(viewController)
        }

        let appearIMP = imp_implementationWithBlock(unsafeBitCast(appearBlock, to: AnyObject.self))
        originalAppearIMP = method_setImplementation(appearMethod, appearIMP)

        let disappearIMP = imp_implementationWithBlock(unsafeBitCast(disappearBlock, to: AnyObject.self))
        originalDisappearIMP = method_setImplementation(disappearMethod, disappearIMP)

        isActive = true
    }

    /// Emits a `ScreenView` for the currently top-most visible controller, as if it had just
    /// appeared. Used to seed a new session (after a session-id change) with the screen the user
    /// is already viewing, since UIKit won't fire `viewDidAppear` again for an on-screen controller.
    ///
    /// No-op when capture isn't active or no trackable controller is on screen. UIKit access is
    /// hopped onto the main thread, matching where the swizzled callbacks run.
    func captureCurrent() {
        guard isActive else { return }

        let capture: () -> Void = { [weak self] in
            guard let self, let yield = self.yield else { return }
            guard let top = ViewControllerScreenSource.currentTopViewController() else { return }
            // Mark on-screen so a later spurious `viewDidAppear` for the same controller is deduped.
            self.onScreen.add(top)
            if let screen = ViewControllerScreenSource.screenView(for: top) {
                yield(screen)
            }
        }

        if Thread.isMainThread {
            capture()
        } else {
            DispatchQueue.main.async(execute: capture)
        }
    }

    func stop() {
        guard isActive else { return }

        if let originalAppearIMP,
           let appearMethod = class_getInstanceMethod(
                UIViewController.self,
                ViewControllerScreenSource.viewDidAppearSelector
           ) {
            _ = method_setImplementation(appearMethod, originalAppearIMP)
        }
        if let originalDisappearIMP,
           let disappearMethod = class_getInstanceMethod(
                UIViewController.self,
                ViewControllerScreenSource.viewDidDisappearSelector
           ) {
            _ = method_setImplementation(disappearMethod, originalDisappearIMP)
        }

        self.originalAppearIMP = nil
        self.originalDisappearIMP = nil
        self.yield = nil
        self.onScreen.removeAllObjects()
        isActive = false
    }

    // MARK: - Derivation (pure, testable)

    /// Builds a `ScreenView` for a controller, or `nil` when it should not be tracked.
    static func screenView(for viewController: UIViewController) -> ScreenView? {
        guard shouldTrack(viewController) else { return nil }

        let className = String(describing: type(of: viewController))
        let screenId = NSStringFromClass(type(of: viewController))

        let provider = viewController as? LDScreenNameProviding
        let name = provider?.ldScreenName
            ?? nonEmpty(viewController.title)
            ?? nonEmpty(viewController.navigationItem.title)
            ?? cleanedName(fromClass: className)

        return ScreenView(
            name: name,
            screenClass: className,
            screenId: screenId,
            category: provider?.ldScreenCategory
        )
    }

    /// Filters out container and system (UIKit-private) controllers.
    static func shouldTrack(_ viewController: UIViewController) -> Bool {
        // Explicitly allow controllers opting in via the provider protocol.
        if viewController is LDScreenNameProviding { return true }

        if viewController is UINavigationController
            || viewController is UITabBarController
            || viewController is UISplitViewController
            || viewController is UIPageViewController
            || viewController is UIInputViewController {
            return false
        }

        let className = NSStringFromClass(type(of: viewController))
        if className.hasPrefix("UI") || className.hasPrefix("_") {
            return false
        }

        return true
    }

    /// Turns a class name into a human-readable default screen name, e.g.
    /// `ProfileViewController` -> `Profile`, `MyApp.HomeVC` -> `Home`.
    static func cleanedName(fromClass className: String) -> String {
        // Drop any module prefix ("MyApp.ProfileViewController" -> "ProfileViewController").
        var name = className.split(separator: ".").last.map(String.init) ?? className
        for suffix in ["ViewController", "Controller", "VC"] {
            if name.hasSuffix(suffix), name.count > suffix.count {
                name = String(name.dropLast(suffix.count))
                break
            }
        }
        return name.isEmpty ? className : name
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// The top-most visible view controller in the active foreground key window, or `nil`.
    static func currentTopViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }

        return topViewController(from: keyWindow?.rootViewController)
    }

    /// Resolves the visible leaf controller below [root], descending through presented controllers
    /// and the standard container controllers. Pure and testable (no UIKit globals).
    static func topViewController(from root: UIViewController?) -> UIViewController? {
        guard let root else { return nil }

        if let presented = root.presentedViewController {
            return topViewController(from: presented)
        }

        switch root {
        case let nav as UINavigationController:
            return topViewController(from: nav.visibleViewController) ?? nav
        case let tab as UITabBarController:
            return topViewController(from: tab.selectedViewController) ?? tab
        default:
            return root
        }
    }
}
#endif
