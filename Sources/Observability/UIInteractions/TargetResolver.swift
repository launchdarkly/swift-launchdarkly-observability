import UIKit

protocol TargetResolving {
    
}

final class TargetResolver: TargetResolving {

    func interaction(view: UIView?, window: UIWindow, event: UIEvent) -> TouchTarget? {
        guard let firstTouch = event.allTouches?.first else {
            return nil
        }
        
        guard firstTouch.type == .direct else {
            return nil
        }
        
        let point = firstTouch.location(in: window)
        let hitView = window.hitTest(point, with: nil) ?? view
        let semanticView = nearestSemanticView(view: hitView)
        let rectWin = semanticView.convert(semanticView.bounds, to: window)
        let target = TouchTarget(className: String(describing: type(of: semanticView)),
                                 accessibilityIdentifier: semanticView.accessibilityIdentifier,
                                 isAccessibilityElement: semanticView.isAccessibilityElement,
                                 rectInWindow: rectWin,
                                 rectOnScreen: window.convert(rectWin, to: nil),
                                 rowIndex: nil)
        
        return target
    }
    
    private func nearestSemanticView(view: UIView) -> UIVIew {
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
