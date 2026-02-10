import UIKit

class SessionReplayAssociatedObjects: NSObject {
    private static var ignoreUIViewKey: Int = 0
    private static var uiViewMaskKey: Int = 0

    private override init() {}
    
    static public func ignoreUIView(_ view: UIView, isEnabled: Bool = true) {
        objc_setAssociatedObject(view, &ignoreUIViewKey, isEnabled ? 1 : 0, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    static public func shouldIgnoreUIView(_ view: UIView) -> Bool? {
        guard let value = (objc_getAssociatedObject(view, &ignoreUIViewKey) as? Int) else { return nil }
        return value == 1
    }
    
    static public func maskUIView(_ view: UIView, isEnabled: Bool = true) {
        objc_setAssociatedObject(view, &uiViewMaskKey, isEnabled ? 1 : 0, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    static public func shouldMaskUIView(_ view: UIView) -> Bool? {
        guard let value = (objc_getAssociatedObject(view, &uiViewMaskKey) as? Int) else { return nil }
        return value == 1
    }
}

    
