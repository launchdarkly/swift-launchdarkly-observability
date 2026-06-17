#if canImport(UIKit)
import UIKit

public struct TouchTarget: Sendable {
    public let className: String?
    public let accessibilityIdentifier: String?
    /// Developer-supplied analytics identifier set via `.ldClick(_:)` (SwiftUI) / `UIView.ldId(_:)`
    /// (UIKit). Preferred over `accessibilityIdentifier` when resolving `event.id` for `click` events.
    public let ldId: String?
    public let text: String?
    public let isAccessibilityElement: Bool?
    public let rectInWindow: CGRect
    public let rectOnScreen: CGRect
    public let rowIndex: IndexPath?
    public let sceneId: String?
    
    public init(className: String?, accessibilityIdentifier: String?, ldId: String? = nil, text: String? = nil, isAccessibilityElement: Bool?, rectInWindow: CGRect, rectOnScreen: CGRect, rowIndex: IndexPath?, sceneId: String?) {
        // Make sure we have Swift string not NSString to transer struct between threads
        self.className = className.map { String($0) }
        self.accessibilityIdentifier = accessibilityIdentifier.map { String($0) }
        self.ldId = ldId.map { String($0) }
        self.text = text.map { String($0) }
        self.isAccessibilityElement = isAccessibilityElement
        self.rectInWindow = rectInWindow
        self.rectOnScreen = rectOnScreen
        self.rowIndex = rowIndex
        self.sceneId = sceneId
    }
}

protocol TargetResolving {
    func resolve(view: UIView?, window: UIWindow, event: UIEvent) -> TouchTarget?
    func resolve(press: UIPress, window: UIWindow) -> TouchTarget?
}

final class TargetResolver: TargetResolving {
    init() {
        
    }
    
    func resolve(view: UIView?, window: UIWindow, event: UIEvent) -> TouchTarget? {
        guard let firstTouch = event.allTouches?.first else {
            return nil
        }
        
        let point = firstTouch.location(in: window)
        guard let hitView = window.hitTest(point, with: nil) ?? view else {
            return nil
        }
        
        let semanticView = nearestSemanticView(view: hitView)
        let ldId = resolveLdId(hitView: hitView, windowPoint: point)
        return touchTarget(for: semanticView, ldId: ldId, window: window)
    }

    func resolve(press: UIPress, window: UIWindow) -> TouchTarget? {
        guard let hitView = press.responder as? UIView else { return nil }
        return touchTarget(for: nearestSemanticView(view: hitView), ldId: ldIdWalkingUp(from: hitView), window: window)
    }
    
    private func touchTarget(for semanticView: UIView, ldId: String?, window: UIWindow) -> TouchTarget {
        let rectWin = semanticView.convert(semanticView.bounds, to: window)
        return TouchTarget(className: String(describing: type(of: semanticView)),
                           accessibilityIdentifier: semanticView.accessibilityIdentifier,
                           ldId: ldId,
                           text: semanticView.extractViewInfo().title,
                           isAccessibilityElement: semanticView.isAccessibilityElement,
                           rectInWindow: rectWin,
                           rectOnScreen: window.convert(rectWin, to: nil),
                           rowIndex: nil,
                           sceneId: window.windowScene?.session.persistentIdentifier)
    }

    /// Resolves the developer-supplied analytics id for a tap.
    ///
    /// SwiftUI taps are supplied via the `.ldClick(_:)` modifier, whose gesture records the id in
    /// `LdClickRegistry` during the tap; since the SDK calls the original `UIWindow.sendEvent` (which
    /// fires that gesture) before resolving the target, the id is available here in the same event
    /// cycle. UIKit views use `UIView.ldId(_:)`, read by walking up the view hierarchy. Returns `nil`
    /// when none is found.
    ///
    /// Priority, most to least precise:
    /// 1. A `.ldClick(_:)` gesture recorded at this exact point (SwiftUI, location-matched).
    /// 2. `UIView.ldId(_:)` on the hit view or an ancestor (UIKit).
    /// 3. A locationless `.ldClick(_:)` entry (older SwiftUI versions that report no coordinates),
    ///    used only as a last resort so it can't mask a real UIKit id or bleed into a later tap.
    private func resolveLdId(hitView: UIView, windowPoint: CGPoint) -> String? {
        if let id = LdClickRegistry.shared.id(at: windowPoint) {
            return id
        }
        if let id = ldIdWalkingUp(from: hitView) {
            return id
        }
        return LdClickRegistry.shared.locationlessId()
    }

    /// Walks up from [view] returning the nearest ancestor's `ldId` (set via `UIView.ldId(_:)`), or `nil`.
    private func ldIdWalkingUp(from view: UIView) -> String? {
        var v: UIView? = view
        while let cur = v {
            if let id = LdIdStorage.get(cur), !id.isEmpty { return id }
            v = cur.superview
        }
        return nil
    }
    
    private func nearestSemanticView(view: UIView) -> UIView {
        var v: UIView? = view
        while let cur = v {
            if cur is UIControl
                || cur is UITableViewCell
                || cur is UICollectionViewCell
                || cur is UINavigationBar
                || cur is UITabBar { return cur }
            if cur.isAccessibilityElement { return cur }
            if cur.superview == nil { return cur }
            if let id = cur.accessibilityIdentifier, !id.isEmpty { return cur }
            
            v = cur.superview
        }
        
        return view
    }
}
#endif
