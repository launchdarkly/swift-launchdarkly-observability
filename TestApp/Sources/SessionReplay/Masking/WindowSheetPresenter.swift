#if os(iOS)
import UIKit
import SwiftUI

enum DimSizing: String, CaseIterable {
    case bounded = "Bounded"
    case up = "Up"
    case bottom = "Bottom"
    case left = "Left"
    case right = "Right"

    func dimFrame(for bounds: CGRect) -> CGRect {
        let w = bounds.width, h = bounds.height
        switch self {
        case .bounded: return bounds
        case .up:      return CGRect(x: 0, y: -h, width: w, height: h * 2)
        case .bottom:  return CGRect(x: 0, y: 0, width: w, height: h * 2)
        case .left:    return CGRect(x: -w, y: 0, width: w * 2, height: h)
        case .right:   return CGRect(x: 0, y: 0, width: w * 2, height: h)
        }
    }
}

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

    func presentViewController(_ viewController: UIViewController, windowFrame: CGRect? = nil) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        if let windowFrame {
            window.frame = windowFrame
        }
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
