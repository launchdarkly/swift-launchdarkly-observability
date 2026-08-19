#if os(iOS)
import SwiftUI
import UIKit

extension View {
    /// Installs a single snapshot control in its own passthrough window, so it stays reachable from
    /// every screen — including sheets and UIKit-presented content — instead of being added per screen.
    func floatingSnapshotButton() -> some View {
        modifier(FloatingSnapshotButtonInstaller())
    }
}

private struct FloatingSnapshotButtonInstaller: ViewModifier {
    private let didBecomeActive = NotificationCenter.default
        .publisher(for: UIApplication.didBecomeActiveNotification)

    func body(content: Content) -> some View {
        content
            .onAppear { FloatingSnapshotButtonWindow.install() }
            .onReceive(didBecomeActive) { _ in FloatingSnapshotButtonWindow.install() }
    }
}

private final class FloatingSnapshotButtonWindow: UIWindow {
    private static var shared: FloatingSnapshotButtonWindow?

    static func install() {
        guard shared == nil, let scene = foregroundScene else { return }

        let window = FloatingSnapshotButtonWindow(windowScene: scene)
        // Above the app's own overlay windows (see `WindowSheetPresenter`) so the control is never
        // covered by the screens it is used to capture.
        window.windowLevel = .alert + 10
        window.backgroundColor = .clear
        window.rootViewController = FloatingSnapshotButtonController()
        window.isHidden = false
        shared = window
    }

    private static var foregroundScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        // A hit on the bare window means the touch missed the button, so let the app's windows have it.
        return hit === self ? nil : hit
    }
}

private final class FloatingSnapshotButtonController: UIViewController {
    private static let buttonSize = CGSize(width: 56, height: 56)
    private static let margin: CGFloat = 16

    private let button = UIHostingController(rootView: SnapshotButton())
    private var buttonCenter: CGPoint?

    override func loadView() {
        view = PassthroughView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        addChild(button)
        button.view.backgroundColor = .clear
        view.addSubview(button.view)
        button.didMove(toParent: self)

        button.view.addGestureRecognizer(
            UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let center = clamped(buttonCenter ?? defaultCenter)
        buttonCenter = center
        button.view.frame = CGRect(origin: .zero, size: Self.buttonSize)
        button.view.center = center
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        gesture.setTranslation(.zero, in: view)
        let center = clamped(
            CGPoint(x: button.view.center.x + translation.x, y: button.view.center.y + translation.y)
        )
        buttonCenter = center
        button.view.center = center
    }

    private var defaultCenter: CGPoint {
        let insets = view.safeAreaInsets
        return CGPoint(
            x: view.bounds.maxX - insets.right - Self.margin - Self.buttonSize.width / 2,
            y: view.bounds.maxY - insets.bottom - Self.margin - Self.buttonSize.height / 2
        )
    }

    private func clamped(_ center: CGPoint) -> CGPoint {
        let insets = view.safeAreaInsets
        let halfWidth = Self.buttonSize.width / 2
        let halfHeight = Self.buttonSize.height / 2
        let minX = view.bounds.minX + insets.left + halfWidth
        let maxX = view.bounds.maxX - insets.right - halfWidth
        let minY = view.bounds.minY + insets.top + halfHeight
        let maxY = view.bounds.maxY - insets.bottom - halfHeight
        return CGPoint(
            x: min(max(center.x, minX), max(minX, maxX)),
            y: min(max(center.y, minY), max(minY, maxY))
        )
    }
}

private final class PassthroughView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        subviews.contains { !$0.isHidden && $0.alpha > 0 && $0.frame.contains(point) }
    }
}
#endif
