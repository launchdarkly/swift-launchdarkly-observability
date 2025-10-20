import UIKit

public struct TouchTarget: Sendable {
    public let className: String?
    public let accessibilityIdentifier: String?
    public let isAccessibilityElement: Bool?
    public let rectInWindow: CGRect
    public let rectOnScreen: CGRect
    public let rowIndex: IndexPath?
    public let sceneId: String?
}

protocol TargetResolving {
    func resolve(view: UIView?, window: UIWindow, event: UIEvent) -> TouchTarget?
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
        let rectWin = semanticView.convert(semanticView.bounds, to: window)
        let target = TouchTarget(className: String(describing: type(of: semanticView)),
                                 accessibilityIdentifier: semanticView.accessibilityIdentifier,
                                 isAccessibilityElement: semanticView.isAccessibilityElement,
                                 rectInWindow: rectWin,
                                 rectOnScreen: window.convert(rectWin, to: nil),
                                 rowIndex: nil,
                                 sceneId: window.windowScene?.session.persistentIdentifier)
        return target
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
            if let id = cur.accessibilityIdentifier, !id.isEmpty { return cur }
            if cur.superview == nil { return cur }
            v = cur.superview
        }
        
        return view
    }
}
