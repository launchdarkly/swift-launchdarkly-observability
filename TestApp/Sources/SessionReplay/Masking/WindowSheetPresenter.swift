#if os(iOS)
import UIKit
import SwiftUI

final class WindowSheetPresenter {
    private var overlayWindow: UIWindow?

    func present<Content: View>(content: Content) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        window.rootViewController = hostingController
        window.backgroundColor = .clear
        window.makeKeyAndVisible()

        overlayWindow = window
    }

    func presentViewController(_ viewController: UIViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        window.rootViewController = viewController
        window.backgroundColor = .clear
        window.makeKeyAndVisible()

        overlayWindow = window
    }

    func dismiss() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
    }
}
#endif
