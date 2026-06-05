#if canImport(UIKit)
import UIKit

/// Captures `screen_view` events by swizzling `UIViewController.viewDidAppear(_:)`.
///
/// Mirrors the swizzle approach in `UIWindowSwizzleSource`: it replaces the
/// implementation, calls the original, then yields the appearing controller as a
/// derived `ScreenView`. Container and system controllers are filtered out so the
/// stream reflects user-meaningful screens only.
final class ViewControllerScreenSource {
    typealias ViewDidAppearRef = @convention(c) (UIViewController, Selector, Bool) -> Void
    private static let viewDidAppearSelector = #selector(UIViewController.viewDidAppear(_:))

    private var isActive = false
    private var originalIMP: IMP?
    private var yield: ((ScreenView) -> Void)?

    init() {}

    func start(yield: @escaping (ScreenView) -> Void) {
        guard !isActive else { return }
        guard let originalMethod = class_getInstanceMethod(
            UIViewController.self,
            ViewControllerScreenSource.viewDidAppearSelector
        ) else { return }

        self.yield = yield

        let swizzledBlock: @convention(block) (UIViewController, Bool) -> Void = { [weak self] viewController, animated in
            if let originalIMP = self?.originalIMP {
                let castedIMP = unsafeBitCast(originalIMP, to: ViewDidAppearRef.self)
                castedIMP(viewController, ViewControllerScreenSource.viewDidAppearSelector, animated)
            }

            guard let self else { return }
            if let screen = ViewControllerScreenSource.screenView(for: viewController) {
                self.yield?(screen)
            }
        }

        let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(swizzledBlock, to: AnyObject.self))
        originalIMP = method_setImplementation(originalMethod, swizzledIMP)
        isActive = true
    }

    func stop() {
        guard isActive, let originalIMP,
              let method = class_getInstanceMethod(
                UIViewController.self,
                ViewControllerScreenSource.viewDidAppearSelector
              ) else { return }

        _ = method_setImplementation(method, originalIMP)
        self.originalIMP = nil
        self.yield = nil
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
}
#endif
