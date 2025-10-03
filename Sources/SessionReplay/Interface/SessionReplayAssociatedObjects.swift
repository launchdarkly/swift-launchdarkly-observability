import UIKit

public class SessionReplayAssociatedObjects: NSObject {
    private static var swiftUIKey: Int = 0
    private static var uiViewMaskKey: Int = 0

    private override init() {}
    
    static public func maskSwiftUI(_ view: UIView, isEnabled: Bool = true) {
        objc_setAssociatedObject(view, &swiftUIKey, isEnabled ? 1 : 0, .OBJC_ASSOCIATION_ASSIGN)
    }
    
    static public func shouldMaskSwiftUI(_ view: UIView) -> Bool? {
        guard let value = (objc_getAssociatedObject(view, &swiftUIKey) as? Int) else { return nil }
        return value == 1
    }
    
    static public func maskUIView(_ view: UIView, isEnabled: Bool = true) {
        objc_setAssociatedObject(view, &uiViewMaskKey, isEnabled ? 1 : 0, .OBJC_ASSOCIATION_ASSIGN)
    }
    
    static public func shouldMaskUIView(_ view: UIView) -> Bool? {
        guard let value = (objc_getAssociatedObject(view, &uiViewMaskKey) as? Int) else { return nil }
        return value == 1
    }

}

